#include <iostream>
#include <string>
#include <vector>
#include <chrono>
#include <opencv2/opencv.hpp>
#include <filesystem> // Requires C++17
#include "ImageSegmenter.h"
#include "nanodet_ncnn.h" // Assuming NanoDet.h includes necessary NCNN headers

namespace fs = std::filesystem;

std::vector<std::string> list_images_in_folder(const std::string& folder_path) {
    std::vector<std::string> image_paths;
    for (const auto& entry : fs::directory_iterator(folder_path)) {
        if (entry.is_regular_file()) {
            std::string extension = entry.path().extension().string();
            if (extension == ".jpg" || extension == ".jpeg" || extension == ".png") {
                image_paths.push_back(entry.path().string());
            }
        }
    }
    return image_paths;
}

void ensure_directory(const std::string& path) {
    if (!fs::exists(path)) {
        fs::create_directories(path);
    }
}

int main(int argc, char** argv) {
    // Parse command-line arguments
    std::string mode = "image"; // Default mode
    std::string input_path;
    std::string output_dir = "./output/";
    int num_threads = 2;
    int target_size = 128;
    float prob_threshold = 0.6f;
    float nms_threshold = 0.65f;
    std::string param_path = "nanodet_128x128_V2_simplified.ncnn.param";
    std::string bin_path = "nanodet_128x128_V2_simplified.ncnn.bin";
    double program_duration = 600.0; // Run for 600 seconds (10 minutes)

    // Parse arguments
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];

        if (arg == "--mode" && i + 1 < argc) {
            mode = argv[++i];
        }
        else if (arg == "--input" && i + 1 < argc) {
            input_path = argv[++i];
        }
        else if (arg == "--output" && i + 1 < argc) {
            output_dir = argv[++i];
            if (output_dir.back() != '/' && output_dir.back() != '\\') {
                output_dir += '/';
            }
        }
        else if (arg == "--duration" && i + 1 < argc) {
            program_duration = std::stod(argv[++i]);
        }
        else if (arg == "--param" && i + 1 < argc) {
            param_path = argv[++i];
        }
        else if (arg == "--bin" && i + 1 < argc) {
            bin_path = argv[++i];
        }
        else if (arg == "--threads" && i + 1 < argc) {
            num_threads = std::stoi(argv[++i]);
        }
        else if (arg == "--prob" && i + 1 < argc) {
            prob_threshold = std::stof(argv[++i]);
        }
        else if (arg == "--nms" && i + 1 < argc) {
            nms_threshold = std::stof(argv[++i]);
        }
        else if (arg == "--help") {
            std::cout << "Usage: " << argv[0] << " [options]" << std::endl;
            std::cout << "--mode [camera|image|folder]" << std::endl;
            std::cout << "--input [input_path]" << std::endl;
            std::cout << "--output [output_dir]" << std::endl;
            std::cout << "--param [nanodet_param_path]" << std::endl;
            std::cout << "--bin [nanodet_bin_path]" << std::endl;
            std::cout << "--threads [number_of_threads]" << std::endl;
            std::cout << "--prob [probability_threshold]" << std::endl;
            std::cout << "--nms [nms_threshold]" << std::endl;
            std::cout << "--duration [camera run time duration]" << std::endl;
            return 0;
        }
    }

    // Validate inputs
    if (mode != "camera" && input_path.empty()) {
        std::cerr << "Error: Input path is required for image and folder modes." << std::endl;
        return -1;
    }

    // Ensure output directory exists
    ensure_directory(output_dir);

    // Initialize NanoDet
    NanoDet detector(param_path, bin_path, num_threads, target_size, prob_threshold, nms_threshold);

    // Perform warm-up runs for detection
    int warmup_iterations = 5; // Number of warm-up iterations
    cv::Mat warmup_frame = cv::Mat::zeros(128, 128, CV_8UC3); // Dummy frame for warm-up

    for (int i = 0; i < warmup_iterations; ++i) {
        std::vector<Object> warmup_objects;
        detector.detect(warmup_frame, warmup_objects);
        std::cout << "Warm-up run " << (i + 1) << " complete." << std::endl;
    }
    std::cout << "Detection warm-up runs complete." << std::endl;

    // Initialize ImageSegmenter
    ImageSegmenter segmenter(
        1.2,          // gamma
        21,           // blockSize
        3,            // C
        false,        // debug_time
        false,        // debug_parts
        output_dir    // output_path (for debug images if enabled)
    );

   
    // Variables for timing
    std::chrono::high_resolution_clock::time_point start_time, end_time;
    double detection_time = 0.0;
    double segmentation_time = 0.0;

    if (mode == "camera") {
        


        // Camera mode
        cv::VideoCapture cap(0); // Use first camera device
        if (!cap.isOpened()) {
            std::cerr << "Error: Unable to open the camera." << std::endl;
            return -1;
        }

        // Before entering the main loop, discard initial frames
        int warmup_frames = 5;
        for (int i = 0; i < warmup_frames; ++i) {
            cv::Mat temp_frame;
            cap >> temp_frame;
            if (temp_frame.empty()) {
                std::cerr << "Warning: Blank frame grabbed during warm-up." << std::endl;
            }
            // Optionally, introduce a small delay to allow the camera to adjust
            // std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }

        std::cout << "Camera warm-up complete. Starting main loop." << std::endl;

        // Variables for processing times
        int frame_count = 0;
        auto program_start_time = std::chrono::steady_clock::now();
        auto fps_start_time = program_start_time;

        double total_detection_time = 0.0;
        double total_segmentation_time = 0.0;
        double total_processing_time = 0.0;
        double max_detection_time = 0.0;
        double max_segmentation_time = 0.0;
        double max_total_time = 0.0;

        while (true) {
            cv::Mat frame;
            cap >> frame;
            if (frame.empty()) {
                std::cerr << "Error: Blank frame grabbed." << std::endl;
                break;
            }

            auto frame_start_time = std::chrono::high_resolution_clock::now();

            // Measure detection time
            auto start_time = std::chrono::high_resolution_clock::now();
            std::vector<Object> objects;
            detector.detect(frame, objects);
            auto end_time = std::chrono::high_resolution_clock::now();
            double detection_time = std::chrono::duration<double, std::milli>(end_time - start_time).count();
            total_detection_time += detection_time;
            if (detection_time > max_detection_time) {
                max_detection_time = detection_time;
            }

            // Prepare segmentation time variable
            double segmentation_time = 0.0;

            if (!objects.empty()) {
                // Log the frame number when object is detected
                std::cout << "Objects detected in frame " << frame_count << "." << std::endl;

                // For each detected object, perform segmentation
                std::vector<cv::Mat> object_clips;
                detector.extract_object_clips_clone(frame, objects, object_clips);

                for (size_t i = 0; i < object_clips.size(); ++i) {
                    // Resize the object image if its height is greater than 100 pixels
                    cv::Mat obj_image = object_clips[i];
                    int original_height = obj_image.rows;

                    if (original_height > 100) {
                        double scale_factor = 100.0 / original_height;
                        int new_width = static_cast<int>(obj_image.cols * scale_factor);
                        int new_height = 100;

                        // Ensure new dimensions are valid
                        if (new_width > 0 && new_height > 0) {
                            cv::resize(obj_image, obj_image, cv::Size(new_width, new_height), 0, 0, cv::INTER_AREA);
                        }
                        else {
                            std::cerr << "Error: Invalid dimensions after resizing for frame " << frame_count << ", object " << i << "." << std::endl;
                            continue;
                        }

                        // Measure segmentation time excluding image saving
                        start_time = std::chrono::high_resolution_clock::now();
                        cv::Mat segmented = segmenter.segmentImage(obj_image);
                        end_time = std::chrono::high_resolution_clock::now();
                        double current_segmentation_time = std::chrono::duration<double, std::milli>(end_time - start_time).count();
                        segmentation_time += current_segmentation_time;
                        total_segmentation_time += current_segmentation_time;
                        if (current_segmentation_time > max_segmentation_time) {
                            max_segmentation_time = current_segmentation_time;
                        }

                        if (segmented.empty()) {
                            std::cerr << "Error: Segmented image is empty after segmentation for frame " << frame_count << ", object " << i << "." << std::endl;
                            continue;
                        }

                        // Save segmented image (not included in segmentation time)
                        std::string output_filename = output_dir + "frame_" + std::to_string(frame_count) + "_object_" + std::to_string(i) + ".png";
                        bool save_success = cv::imwrite(output_filename, segmented);
                        if (!save_success) {
                            std::cerr << "Error: Failed to write image to " << output_filename << std::endl;
                        }
                    }

                   
                }
            }

            auto frame_end_time = std::chrono::high_resolution_clock::now();
            double total_frame_time = std::chrono::duration<double, std::milli>(frame_end_time - frame_start_time).count();
            total_processing_time += total_frame_time;
            if (total_frame_time > max_total_time) {
                max_total_time = total_frame_time;
            }

            frame_count++;

            // Calculate and log stats every 10 seconds
            auto current_time = std::chrono::steady_clock::now();
            double elapsed_seconds = std::chrono::duration<double>(current_time - fps_start_time).count();

            if (elapsed_seconds >= 10.0) {
                double fps = frame_count / elapsed_seconds;
                std::cout << "Processed " << frame_count << " frames in " << elapsed_seconds << " seconds." << std::endl;
                std::cout << "Average FPS: " << fps << std::endl;

                // Optionally, reset frame count and timers if you want per-interval stats
                // frame_count = 0;
                // total_detection_time = 0.0;
                // total_segmentation_time = 0.0;
                // total_processing_time = 0.0;
                // fps_start_time = current_time;
            }

            // Check if program duration has been reached
            double total_program_time = std::chrono::duration<double>(current_time - program_start_time).count();
            if (total_program_time >= program_duration) {
                std::cout << "Program has been running for " << total_program_time << " seconds. Exiting." << std::endl;
                break;
            }

            // Optionally, sleep for a short duration if you want to control the frame rate
            // std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
        cap.release();

        // After exiting the loop, compute and display the averages and maximums
        if (frame_count > 0) {
            double avg_detection_time = total_detection_time / frame_count;
            double avg_segmentation_time = total_segmentation_time / frame_count;
            double avg_total_time = total_processing_time / frame_count;

            std::cout << "\n=== Processing Statistics ===" << std::endl;
            std::cout << "Total frames processed: " << frame_count << std::endl;
            std::cout << "Average detection time per frame: " << avg_detection_time << " ms" << std::endl;
            std::cout << "Average segmentation time per frame: " << avg_segmentation_time << " ms" << std::endl;
            std::cout << "Average total processing time per frame: " << avg_total_time << " ms" << std::endl;
            std::cout << "Maximum detection time: " << max_detection_time << " ms" << std::endl;
            std::cout << "Maximum segmentation time: " << max_segmentation_time << " ms" << std::endl;
            std::cout << "Maximum total processing time per frame: " << max_total_time << " ms" << std::endl;
        }
        else {
            std::cout << "No frames were processed." << std::endl;
        }
    }


    else if (mode == "image") {
        // Single image mode
        cv::Mat image = cv::imread(input_path);
        if (image.empty()) {
            std::cerr << "Error: Unable to load image: " << input_path << std::endl;
            return -1;
        }
        ImageSegmenter segmenter(
            1.2,          // gamma
            21,           // blockSize
            3,            // C
            false,        // debug_time
            true,        // debug_parts
            output_dir    // output_path (for debug images if enabled)
        );;
        // Detect objects
        std::vector<Object> objects;
        start_time = std::chrono::high_resolution_clock::now();
        detector.detect(image, objects);
        end_time = std::chrono::high_resolution_clock::now();
        detection_time = std::chrono::duration<double, std::milli>(end_time - start_time).count();

        if (objects.empty()) {
            std::cout << "No objects detected in image: " << input_path << "." << std::endl;
            return 0;
        }

        // Extract object clips
        std::vector<cv::Mat> object_clips;
        detector.extract_object_clips_clone(image, objects, object_clips);

        for (size_t i = 0; i < object_clips.size(); ++i) {
            // Segment the object clip
            int original_height = object_clips[i].rows;

            if (original_height > 100) {
                double scale_factor = 100.0 / original_height;
                int new_width = static_cast<int>(object_clips[i].cols * scale_factor);
                int new_height = 100;

                // Ensure new dimensions are valid
                if (new_width > 0 && new_height > 0) {
                    cv::resize(object_clips[i], object_clips[i], cv::Size(new_width, new_height), 0, 0, cv::INTER_AREA);
                }
                
            }
            start_time = std::chrono::high_resolution_clock::now();
            cv::Mat segmented = segmenter.segmentImage(object_clips[i]);
            end_time = std::chrono::high_resolution_clock::now();
            segmentation_time = std::chrono::duration<double, std::milli>(end_time - start_time).count();

            // Save segmented image
            std::string output_filename = output_dir + "image_object_" + std::to_string(i) + ".png";
            cv::imwrite(output_filename, segmented);

            std::cout << "Object " << i << ": Detection Time = "
                << detection_time << " ms, Segmentation Time = " << segmentation_time << " ms" << std::endl;
        }
    }
    else if (mode == "folder") {
        // Folder mode
        std::vector<std::string> image_paths = list_images_in_folder(input_path);
        if (image_paths.empty()) {
            std::cerr << "Error: No images found in folder: " << input_path << std::endl;
            return -1;
        }

        int image_count = 0;
        double total_detection_time = 0.0;
        double total_segmentation_time = 0.0;
        double total_processing_time = 0.0;
        double max_detection_time = 0.0;
        double max_segmentation_time = 0.0;
        double max_processing_time = 0.0;
        double min_detection_time = std::numeric_limits<double>::max();
        double min_segmentation_time = std::numeric_limits<double>::max();
        double min_processing_time = std::numeric_limits<double>::max();
        int images_with_detections = 0;

        for (const auto& img_path : image_paths) {
            cv::Mat image = cv::imread(img_path);
            if (image.empty()) {
                std::cerr << "Error: Unable to load image: " << img_path << std::endl;
                continue;
            }

            // Detect objects
            start_time = std::chrono::high_resolution_clock::now();
            std::vector<Object> objects;
            detector.detect(image, objects);
            end_time = std::chrono::high_resolution_clock::now();
            detection_time = std::chrono::duration<double, std::milli>(end_time - start_time).count();

            total_detection_time += detection_time;
            if (detection_time > max_detection_time) max_detection_time = detection_time;
            if (detection_time < min_detection_time) min_detection_time = detection_time;

            if (objects.empty()) {
                std::cout << "No objects detected in image: " << img_path << "." << std::endl;
                image_count++;
                continue;
            }

            images_with_detections++;

            // Extract object clips
            std::vector<cv::Mat> object_clips;
            detector.extract_object_clips_clone(image, objects, object_clips);

            // Get the original image name without extension
            std::string image_name = img_path.substr(img_path.find_last_of("/") + 1);
            std::string base_name = img_path.substr(img_path.find_last_of("/") + 1, image_name.find_last_of("."));

            for (size_t i = 0; i < object_clips.size(); ++i) {
                // Resize the object image if its height is greater than 100 pixels
                cv::Mat obj_image = object_clips[i];
                int original_height = obj_image.rows;

                if (original_height > 100) {
                    double scale_factor = 100.0 / original_height;
                    int new_width = static_cast<int>(obj_image.cols * scale_factor);
                    int new_height = 100;

                    // Ensure new dimensions are valid
                    if (new_width > 0 && new_height > 0) {
                        cv::resize(obj_image, obj_image, cv::Size(new_width, new_height), 0, 0, cv::INTER_AREA);
                    }
                    else {

                        continue;
                    }
                }
                // Segment the object clip
                start_time = std::chrono::high_resolution_clock::now();
                cv::Mat segmented = segmenter.segmentImage(obj_image);
                end_time = std::chrono::high_resolution_clock::now();
                segmentation_time = std::chrono::duration<double, std::milli>(end_time - start_time).count();

                total_segmentation_time += segmentation_time;
                if (segmentation_time > max_segmentation_time) max_segmentation_time = segmentation_time;
                if (segmentation_time < min_segmentation_time) min_segmentation_time = segmentation_time;

                // Save segmented or detected image
                std::string output_filename = output_dir + base_name + "_object_" + std::to_string(i) + ".png";
                if (!segmented.empty()) {
                    int newHeight = 16;
                    double aspectRatio = static_cast<double>(segmented.cols) / static_cast<double>(segmented.rows);
                    int newWidth = static_cast<int>(newHeight * aspectRatio);
                    cv::Mat resizedImage;
                    cv::resize(segmented, resizedImage, cv::Size(newWidth, newHeight));

                    cv::imwrite(output_filename, resizedImage);
                }
                else {
                    int newHeight = 16;
                    double aspectRatio = static_cast<double>(object_clips[i].cols) / static_cast<double>(object_clips[i].rows);
                    int newWidth = static_cast<int>(newHeight * aspectRatio);
                    cv::Mat resizedImage;
                    cv::resize(object_clips[i], resizedImage, cv::Size(newWidth, newHeight));
                    std::cerr << "Error: Segmented image is empty for image " << img_path << ", saving detected image instead." << std::endl;
                    cv::imwrite(output_filename, resizedImage);
                }

                std::cout << "Image " << base_name << ", Object " << i << ": Detection Time = " << detection_time << " ms, Segmentation Time = " << segmentation_time << " ms" << std::endl;
            }

            total_processing_time += detection_time + segmentation_time;
            if (detection_time + segmentation_time > max_processing_time) max_processing_time = detection_time + segmentation_time;
            if (detection_time + segmentation_time < min_processing_time) min_processing_time = detection_time + segmentation_time;

            image_count++;
        }

        // Calculate and print statistics
        int total_images = image_count;
        double avg_detection_time = total_detection_time / total_images;
        double avg_segmentation_time = total_segmentation_time / total_images;
        double avg_processing_time = total_processing_time / total_images;

        std::cout << "\n=== Processing Statistics ===" << std::endl;
        std::cout << "Total images processed: " << total_images << std::endl;
        std::cout << "Images with detections: " << images_with_detections << std::endl;
        std::cout << "Average detection time: " << avg_detection_time << " ms" << std::endl;
        std::cout << "Average segmentation time: " << avg_segmentation_time << " ms" << std::endl;
        std::cout << "Average processing time: " << avg_processing_time << " ms" << std::endl;
        std::cout << "Max detection time: " << max_detection_time << " ms" << std::endl;
        std::cout << "Min detection time: " << min_detection_time << " ms" << std::endl;
        std::cout << "Max segmentation time: " << max_segmentation_time << " ms" << std::endl;
        std::cout << "Min segmentation time: " << min_segmentation_time << " ms" << std::endl;
        std::cout << "Max processing time: " << max_processing_time << " ms" << std::endl;
        std::cout << "Min processing time: " << min_processing_time << " ms" << std::endl;
    }
    else {
        std::cerr << "Error: Invalid mode selected. Use 'camera', 'image', or 'folder'." << std::endl;
        return -1;
    }




    return 0;
}
