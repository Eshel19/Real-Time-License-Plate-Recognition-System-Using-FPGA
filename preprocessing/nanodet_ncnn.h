#ifndef NANODET_NCNN_H
#define NANODET_NCNN_H

#include "ncnn/net.h"
#include <opencv2/core/core.hpp>
#include <vector>


struct Object
{
    cv::Rect_<float> rect;
    int label;
    float prob;
};

class NanoDet
{
public:
    NanoDet(const std::string& param_path, const std::string& bin_path, int num_threads, int target_size, float prob_threshold, float nms_threshold);
    ~NanoDet();
    ncnn::Net* Net;
    int target_size;
    float prob_threshold;
    float nms_threshold;
    int detect(const cv::Mat& bgr, std::vector<Object>& objects);
    void draw_objects(const cv::Mat& input_image, cv::Mat& output_image, const std::vector<Object>& objects);
    void extract_object_clips_clone(const cv::Mat& input_image, const std::vector<Object>& objects, std::vector<cv::Mat>& object_clips);
    void extract_object_clips_reference(const cv::Mat& input_image, const std::vector<Object>& objects, std::vector<cv::Mat>& object_clips);
    void extract_and_resize_object_clips(const cv::Mat& input_image, const std::vector<Object>& objects, std::vector<cv::Mat>& object_clips, const cv::Size& target_size);

private:
    void generate_proposals(const ncnn::Mat& pred, int stride, const ncnn::Mat& in_pad, float prob_threshold, std::vector<Object>& objects);
    void qsort_descent_inplace(std::vector<Object>& faceobjects, int left, int right);
    void qsort_descent_inplace(std::vector<Object>& faceobjects);
    void nms_sorted_bboxes(const std::vector<Object>& faceobjects, std::vector<int>& picked, float nms_threshold, bool agnostic);
    float intersection_area(const Object& a, const Object& b);
    int num_threads;

};

#endif // NANODET_H
