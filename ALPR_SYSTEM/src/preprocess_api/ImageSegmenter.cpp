// ImageSegmenter.cpp

#include "ImageSegmenter.h"
#include <algorithm>
#include <cmath>
#include <numeric>
#include <chrono>
#include <iostream>
#include <filesystem>

namespace fs = std::filesystem;

ImageSegmenter::ImageSegmenter(
    double gamma,
    int blockSize,
    int C,
    bool debug_time,
    bool debug_parts,
    const std::string& output_path
) : gamma_(gamma), blockSize_(blockSize), C_(C), debug_time_(debug_time), debug_parts_(debug_parts), output_path_(output_path) {
    // Create output directory if debug parts is enabled
    if (debug_parts_) {
        fs::create_directories(output_path_);
    }
}

cv::Mat ImageSegmenter::adjustGamma(const cv::Mat& image) {
    if (debug_time_) {
        std::cout << "Starting adjustGamma..." << std::endl;
    }
    auto start_time = std::chrono::high_resolution_clock::now();

    cv::Mat lut_matrix(1, 256, CV_8UC1);
    uchar* ptr = lut_matrix.ptr();
    double inv_gamma = 1.0 / gamma_;
    for (int i = 0; i < 256; i++) {
        ptr[i] = cv::saturate_cast<uchar>(pow((i / 255.0), inv_gamma) * 255.0);
    }
    cv::Mat result;
    cv::LUT(image, lut_matrix, result);

    if (debug_time_) {
        auto end_time = std::chrono::high_resolution_clock::now();
        std::cout << "adjustGamma took: "
            << std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time).count()
            << " ms" << std::endl;
    }
    return result;
}

void ImageSegmenter::processImage(const cv::Mat& image, cv::Mat& adaptiveThresholded, cv::Mat& grayImage) {
    if (debug_time_) {
        std::cout << "Starting processImage..." << std::endl;
    }
    auto start_time = std::chrono::high_resolution_clock::now();

    // Convert to grayscale
    cv::cvtColor(image, grayImage, cv::COLOR_BGR2GRAY);

    // Adjust gamma
    cv::Mat grayCorrected = adjustGamma(grayImage);

    // Adaptive thresholding
    cv::adaptiveThreshold(
        grayCorrected, adaptiveThresholded, 255,
        cv::ADAPTIVE_THRESH_GAUSSIAN_C, cv::THRESH_BINARY_INV,
        blockSize_, C_
    );

    if (debug_parts_) {
        cv::imwrite(output_path_ + "adaptiveThresholded.png", adaptiveThresholded);
    }

    if (debug_time_) {
        auto end_time = std::chrono::high_resolution_clock::now();
        std::cout << "processImage took: "
            << std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time).count()
            << " ms" << std::endl;
    }
}

double ImageSegmenter::calculateAngle(const cv::Vec4i& line) {
    double angle_rad = atan2(line[3] - line[1], line[2] - line[0]);
    double angle_deg = angle_rad * 180.0 / CV_PI;
    return angle_deg;
}

cv::Mat ImageSegmenter::applyVerticalShear(const cv::Mat& image, double angle, bool isBinary) {
    if (debug_time_) {
        std::cout << "Starting applyVerticalShear..." << std::endl;
    }
    auto start_time = std::chrono::high_resolution_clock::now();

    double angle_rad = angle * CV_PI / 180.0;
    double shear_factor = tan(angle_rad);

    int height = image.rows;
    int width = image.cols;

    cv::Mat shear_matrix = (cv::Mat_<double>(2, 3) << 1, 0, 0, shear_factor, 1, -shear_factor * width / 2);
    int new_height = static_cast<int>(height + std::abs(shear_factor * width));

    cv::Mat sheared_image;
    int interpolation = isBinary ? cv::INTER_NEAREST : cv::INTER_LINEAR;
    cv::warpAffine(image, sheared_image, shear_matrix, cv::Size(width, new_height), interpolation, cv::BORDER_REPLICATE);

    if (debug_time_) {
        auto end_time = std::chrono::high_resolution_clock::now();
        std::cout << "applyVerticalShear took: "
            << std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time).count()
            << " ms" << std::endl;
    }

    if (debug_parts_) {
        if (isBinary) {
            cv::imwrite(output_path_ + "sheared_binary.png", sheared_image);
        }
        else {
            cv::imwrite(output_path_ + "sheared_gray.png", sheared_image);
        }
    }

    return sheared_image;
}

std::vector<double> ImageSegmenter::calculateHorizontalRatio(const cv::Mat& image, double middle_start_ratio, double middle_end_ratio) {
    if (debug_time_) {
        std::cout << "Starting calculateHorizontalRatio..." << std::endl;
    }
    auto start_time = std::chrono::high_resolution_clock::now();

    int height = image.rows;
    int width = image.cols;

    int middle_start = static_cast<int>(width * middle_start_ratio);
    int middle_end = static_cast<int>(width * middle_end_ratio);
    int middle_width = middle_end - middle_start;

    std::vector<double> horizontal_prob(height, 0.0);

    for (int y = 0; y < height; ++y) {
        const uchar* row_ptr = image.ptr<uchar>(y);
        int sum = 0;

        for (int x = middle_start; x < middle_end; ++x) {
            sum += row_ptr[x] > 0 ? 1 : 0;
        }

        horizontal_prob[y] = static_cast<double>(sum) / middle_width;
    }

    if (debug_time_) {
        auto end_time = std::chrono::high_resolution_clock::now();
        std::cout << "calculateHorizontalRatio took: "
            << std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time).count()
            << " ms" << std::endl;
    }

    return horizontal_prob;
}

std::vector<std::pair<int, int>> ImageSegmenter::findConsistentSegments(
    const std::vector<double>& horizontal_prob,
    double min_ratio,
    double max_ratio,
    double delta,
    double min_length_ratio
) {
    if (debug_time_) {
        std::cout << "Starting findConsistentSegments..." << std::endl;
    }
    auto start_time = std::chrono::high_resolution_clock::now();

    int total_length = horizontal_prob.size();

    // Adjust min_ratio and max_ratio if needed
    if (max_ratio > 0.85)
        max_ratio = 0.85;
    if (min_ratio < 0.15)
        min_ratio = 0.15;

    int min_length = static_cast<int>(total_length * min_length_ratio);

    std::vector<std::pair<int, int>> segments;
    int start = -1; // Use -1 to represent 'None'
    double temp_avg = 0;
    double total_avg = 0;
    int count = 0;

    for (int i = 0; i < total_length; ++i) {
        double val = horizontal_prob[i];

        if (val < min_ratio && start == -1 && i < total_length - 1) {
            start = i;
            if (horizontal_prob[i + 1] >= min_ratio && horizontal_prob[i + 1] <= max_ratio) {
                total_avg = temp_avg = horizontal_prob[i + 1];
                count = 1;
            }
        }
        else if (val >= min_ratio && val <= max_ratio) {
            if (start != -1) {
                if (std::abs(val - total_avg) > delta) {
                    if (i - start >= min_length) {
                        segments.emplace_back(start, i);
                    }
                    start = -1;
                    count = 0;
                }
                else {
                    temp_avg += val;
                    count++;
                    total_avg = temp_avg / count;
                }
            }
            else if (i != start) {
                total_avg = temp_avg = val;
                start = i;
                count = 1;
            }
        }
        else {
            if (start != -1 && (i - start) >= min_length) {
                if (val < max_ratio) {
                    segments.emplace_back(start, i);
                    start = -1;
                }
                else if ((i - 1 - start) >= min_length) {
                    segments.emplace_back(start, i - 1);
                    start = -1;
                }
            }
            else {
                if (val < min_ratio && i < total_length - 1) {
                    start = i;
                    if (horizontal_prob[i + 1] >= min_ratio && horizontal_prob[i + 1] <= max_ratio) {
                        total_avg = temp_avg = horizontal_prob[i + 1];
                        count = 1;
                    }
                }
                else {
                    start = -1;
                }
            }
        }
    }

    if (start != -1 && (total_length - start) >= min_length) {
        segments.emplace_back(start, total_length - 1);
    }

    if (debug_time_) {
        auto end_time = std::chrono::high_resolution_clock::now();
        std::cout << "findConsistentSegments took: "
            << std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time).count()
            << " ms" << std::endl;
    }

    return segments;
}

cv::Mat ImageSegmenter::padImageToHeight(const cv::Mat& image, int targetHeight) {
    int height = image.rows;
    if (height >= targetHeight) {
        return image;
    }

    int padding = targetHeight - height;

    int padTop = padding / 2;
    int padBottom = padding - padTop;

    cv::Mat padded;
    cv::copyMakeBorder(
        image, padded,
        padTop, padBottom,
        0, 0,
        cv::BORDER_CONSTANT, cv::Scalar(0)
    );
    return padded;
}
cv::Mat ImageSegmenter::segmentImage(const cv::Mat& image) {
    if (debug_time_) {
        std::cout << "Starting segmentImage..." << std::endl;
    }
    auto total_start_time = std::chrono::high_resolution_clock::now();

    // Declare variables for timing
    std::chrono::high_resolution_clock::time_point start_time, end_time;

    cv::Mat adaptiveThresholded, grayImage;

    // Process Image
    if (debug_time_) {
        std::cout << "Processing image (gamma correction and adaptive thresholding)..." << std::endl;
        start_time = std::chrono::high_resolution_clock::now();
    }

    processImage(image, adaptiveThresholded, grayImage);

    if (debug_time_) {
        end_time = std::chrono::high_resolution_clock::now();
        std::cout << "processImage took: "
            << std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time).count()
            << " ms" << std::endl;
    }

    // Line Detection using HoughLinesP
    if (debug_time_) {
        std::cout << "Performing Hough Line Detection..." << std::endl;
        start_time = std::chrono::high_resolution_clock::now();
    }

    std::vector<cv::Vec4i> lines;
    cv::HoughLinesP(
        adaptiveThresholded, lines, 1, CV_PI / 90, 40,
        adaptiveThresholded.cols * 0.5, 2
    );

    if (debug_time_) {
        end_time = std::chrono::high_resolution_clock::now();
        std::cout << "HoughLinesP took: "
            << std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time).count()
            << " ms" << std::endl;
    }

    // Calculate median angle of horizontal lines
    if (debug_time_) {
        std::cout << "Calculating median angle of detected lines..." << std::endl;
        start_time = std::chrono::high_resolution_clock::now();
    }

    std::vector<double> horizontal_angles;
    for (auto& line : lines) {
        double angle = calculateAngle(line);
        if (std::abs(angle) < 45) {
            horizontal_angles.push_back(angle);
        }
    }
    double horizontal_angle = 0.0;
    if (!horizontal_angles.empty()) {
        std::sort(horizontal_angles.begin(), horizontal_angles.end());
        horizontal_angle = horizontal_angles[horizontal_angles.size() / 2];
    }

    if (debug_parts_) {
        std::cout << std::fixed << std::setprecision(2);
        std::cout << "Detected angle (for skew correction): " << horizontal_angle << " degrees" << std::endl;
    }

    if (debug_time_) {
        end_time = std::chrono::high_resolution_clock::now();
        std::cout << "Angle calculation took: "
            << std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time).count()
            << " ms" << std::endl;
    }

    // Apply vertical shear for skew correction
    if (debug_time_) {
        std::cout << "Applying vertical shear for skew correction..." << std::endl;
        start_time = std::chrono::high_resolution_clock::now();
    }

    cv::Mat sheared_binary = applyVerticalShear(adaptiveThresholded, -horizontal_angle, true);
    cv::Mat sheared_gray = applyVerticalShear(grayImage, -horizontal_angle);

    if (debug_time_) {
        end_time = std::chrono::high_resolution_clock::now();
        std::cout << "Skew correction took: "
            << std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time).count()
            << " ms" << std::endl;
    }

    // Calculate horizontal probability
    if (debug_time_) {
        std::cout << "Calculating horizontal probability..." << std::endl;
        start_time = std::chrono::high_resolution_clock::now();
    }

    std::vector<double> horizontal_prob = calculateHorizontalRatio(sheared_binary);

    if (debug_time_) {
        end_time = std::chrono::high_resolution_clock::now();
        std::cout << "Horizontal probability calculation took: "
            << std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time).count()
            << " ms" << std::endl;
    }

    // Find consistent segments
    if (debug_time_) {
        std::cout << "Finding consistent segments..." << std::endl;
        start_time = std::chrono::high_resolution_clock::now();
    }

    double mean_prob = std::accumulate(horizontal_prob.begin(), horizontal_prob.end(), 0.0) / horizontal_prob.size();
    std::vector<std::pair<int, int>> segments = findConsistentSegments(
        horizontal_prob, mean_prob * 0.20, mean_prob * 2, mean_prob
    );

    if (debug_time_) {
        end_time = std::chrono::high_resolution_clock::now();
        std::cout << "Segment detection took: "
            << std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time).count()
            << " ms" << std::endl;
        std::cout << "Number of segments found: " << segments.size() << std::endl;
    }

    // Extract segments and determine maximum height
    if (debug_time_) {
        std::cout << "Extracting segments..." << std::endl;
        start_time = std::chrono::high_resolution_clock::now();
    }

    std::vector<cv::Mat> segment_images;
    int max_height = 0;
    for (size_t idx = 0; idx < segments.size(); ++idx) {
        auto& seg = segments[idx];
        cv::Mat segment = sheared_gray(cv::Range(seg.first, seg.second), cv::Range::all());
        segment_images.push_back(segment);
        if (segment.rows > max_height) {
            max_height = segment.rows;
        }

        if (debug_parts_) {
            // Save the segment image
            cv::imwrite(output_path_ + "segment_" + std::to_string(idx) + ".png", segment);
        }
    }

    if (debug_time_) {
        end_time = std::chrono::high_resolution_clock::now();
        std::cout << "Segment extraction took: "
            << std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time).count()
            << " ms" << std::endl;
    }

    // Pad segments to the same height and concatenate horizontally
    if (debug_time_) {
        std::cout << "Padding segments and concatenating..." << std::endl;
        start_time = std::chrono::high_resolution_clock::now();
    }

    cv::Mat final_image;
    for (size_t i = 0; i < segment_images.size(); ++i) {
        segment_images[i] = padImageToHeight(segment_images[i], max_height);
        if (i == 0) {
            final_image = segment_images[i];
        }
        else {
            cv::hconcat(final_image, segment_images[i], final_image);
        }
    }

    if (debug_parts_) {
        // Save the final concatenated image
        cv::imwrite(output_path_ + "final_segmented_image.png", final_image);
    }

    if (debug_time_) {
        end_time = std::chrono::high_resolution_clock::now();
        std::cout << "Padding and concatenation took: "
            << std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time).count()
            << " ms" << std::endl;
    }

    if (debug_time_) {
        auto total_end_time = std::chrono::high_resolution_clock::now();
        std::cout << "Total segmentImage function took: "
            << std::chrono::duration_cast<std::chrono::milliseconds>(total_end_time - total_start_time).count()
            << " ms" << std::endl;
    }

    return final_image;
}

