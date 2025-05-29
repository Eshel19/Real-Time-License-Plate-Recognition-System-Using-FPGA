// ImageSegmenter.h

#ifndef IMAGE_SEGMENTER_H
#define IMAGE_SEGMENTER_H

#include <opencv2/opencv.hpp>
#include <vector>
#include <string>

class ImageSegmenter {
public:
    // Constructor with default parameters
    ImageSegmenter(
        double gamma = 1.2,
        int blockSize = 21,
        int C = 3,
        bool debug_time = false,
        bool debug_parts = false,
        const std::string& output_path = "./debug_outputs/"
    );

    cv::Mat segmentImage(const cv::Mat& image);

private:
    double gamma_;
    int blockSize_;
    int C_;
    bool debug_time_;
    bool debug_parts_;
    std::string output_path_;

    cv::Mat adjustGamma(const cv::Mat& image);
    void processImage(const cv::Mat& image, cv::Mat& adaptiveThresholded, cv::Mat& grayImage);
    double calculateAngle(const cv::Vec4i& line);
    cv::Mat applyVerticalShear(const cv::Mat& image, double angle, bool isBinary = false);
    std::vector<double> calculateHorizontalRatio(const cv::Mat& image, double middle_start_ratio = 0.25, double middle_end_ratio = 0.75);
    std::vector<std::pair<int, int>> findConsistentSegments(
        const std::vector<double>& horizontal_prob,
        double min_ratio = 0.15,
        double max_ratio = 0.75,
        double delta = 0.2,
        double min_length_ratio = 0.15
    );
    cv::Mat padImageToHeight(const cv::Mat& image, int targetHeight);
};

#endif // IMAGE_SEGMENTER_H
