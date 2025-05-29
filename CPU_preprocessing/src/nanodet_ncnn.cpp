#include "ncnn/net.h"
#include <opencv2/core/core.hpp>
#include <opencv2/highgui/highgui.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#include <vector>
#include <chrono>
#include <iostream>
#include "nanodet_ncnn.h"


NanoDet::NanoDet(const std::string& param_path, const std::string& bin_path, int num_threads = 2, int target_size = 128, float prob_threshold = 0.6f, float nms_threshold = 0.65f)
: num_threads(num_threads), target_size(target_size), prob_threshold(prob_threshold), nms_threshold(nms_threshold)
    {
    this->Net = new ncnn::Net();
    if (this->Net->load_param(param_path.c_str()) != 0)
        return;
    if (this->Net->load_model(bin_path.c_str()) != 0)
        return;
    this->target_size = target_size;
    this->prob_threshold = prob_threshold;
    this->nms_threshold = nms_threshold;
    this->Net->opt.num_threads = num_threads;
    this->Net->opt.use_packing_layout = true;
    this->Net->opt.use_fp16_packed = true;
    this->Net->opt.use_fp16_storage = true;
    this->Net->opt.use_fp16_arithmetic = true;
    this->Net->opt.use_int8_inference = true;
    this->Net->opt.use_vulkan_compute = false;
    }


NanoDet::~NanoDet()
{
    delete this->Net;
}


inline float NanoDet::intersection_area(const Object& a, const Object& b)
{
    cv::Rect_<float> inter = a.rect & b.rect;
    return inter.area();
}


void NanoDet::qsort_descent_inplace(std::vector<Object>& faceobjects, int left, int right)
{
    int i = left;
    int j = right;
    float p = faceobjects[(left + right) / 2].prob;

    while (i <= j)
    {
        while (faceobjects[i].prob > p)
            i++;

        while (faceobjects[j].prob < p)
            j--;

        if (i <= j)
        {
            // swap
            std::swap(faceobjects[i], faceobjects[j]);

            i++;
            j--;
        }
    }

#pragma omp parallel sections
    {
#pragma omp section
        {
            if (left < j) qsort_descent_inplace(faceobjects, left, j);
        }
#pragma omp section
        {
            if (i < right) qsort_descent_inplace(faceobjects, i, right);
        }
    }
}

void NanoDet::qsort_descent_inplace(std::vector<Object>& faceobjects)
{
    if (faceobjects.empty())
        return;

    qsort_descent_inplace(faceobjects, 0, faceobjects.size() - 1);
}

void NanoDet::nms_sorted_bboxes(const std::vector<Object>& faceobjects, std::vector<int>& picked, float nms_threshold, bool agnostic = false)
{
    picked.clear();

    const int n = faceobjects.size();

    std::vector<float> areas(n);
    for (int i = 0; i < n; i++)
    {
        areas[i] = faceobjects[i].rect.area();
    }

    for (int i = 0; i < n; i++)
    {
        const Object& a = faceobjects[i];

        int keep = 1;
        for (int j = 0; j < (int)picked.size(); j++)
        {
            const Object& b = faceobjects[picked[j]];

            if (!agnostic && a.label != b.label)
                continue;

            // intersection over union
            float inter_area = intersection_area(a, b);
            float union_area = areas[i] + areas[picked[j]] - inter_area;
            // float IoU = inter_area / union_area
            if (inter_area / union_area > nms_threshold)
                keep = 0;
        }

        if (keep)
            picked.push_back(i);
    }
}

inline float fast_exp(float x)
{
    union {
        uint32_t i;
        float f;
    } v{};
    v.i = (1 << 23) * (1.4426950409 * x + 126.93490512f);
    return v.f;
}


inline float sigmoid(float x)
{
    return 1.0f / (1.0f + fast_exp(-x));
}

void NanoDet::generate_proposals(const ncnn::Mat& pred, int stride, const ncnn::Mat& in_pad, float prob_threshold, std::vector<Object>& objects)
{
    const int num_grid = pred.h;

    int num_grid_x = pred.w;
    int num_grid_y = pred.h;

    const int num_class = 2;
    const int reg_max_1 = (pred.c - num_class) / 4;

    for (int i = 0; i < num_grid_y; i++)
    {
        for (int j = 0; j < num_grid_x; j++)
        {
            // find label with max score
            int label = -1;
            float score = -FLT_MAX;
            for (int k = 1; k < num_class; k++)
            {
                float s = pred.channel(k).row(i)[j];
                if (s > score)
                {
                    label = k;
                    score = s;
                }
            }

            score = sigmoid(score);

            if (score >= prob_threshold)
            {
                ncnn::Mat bbox_pred(reg_max_1, 4);
                for (int k = 0; k < reg_max_1 * 4; k++)
                {
                    bbox_pred[k] = pred.channel(num_class + k).row(i)[j];
                }
                {
                    ncnn::Layer* softmax = ncnn::create_layer("Softmax");

                    ncnn::ParamDict pd;
                    pd.set(0, 1); // axis
                    pd.set(1, 1);
                    softmax->load_param(pd);

                    ncnn::Option opt;
                    opt.num_threads = 2;
                    opt.use_packing_layout = false;

                    softmax->create_pipeline(opt);

                    softmax->forward_inplace(bbox_pred, opt);

                    softmax->destroy_pipeline(opt);

                    delete softmax;
                }

                float pred_ltrb[4];
                for (int k = 0; k < 4; k++)
                {
                    float dis = 0.f;
                    const float* dis_after_sm = bbox_pred.row(k);
                    for (int l = 0; l < reg_max_1; l++)
                    {
                        dis += l * dis_after_sm[l];
                    }

                    pred_ltrb[k] = dis * stride;
                }

                float pb_cx = j * stride;
                float pb_cy = i * stride;

                float x0 = pb_cx - pred_ltrb[0];
                float y0 = pb_cy - pred_ltrb[1];
                float x1 = pb_cx + pred_ltrb[2];
                float y1 = pb_cy + pred_ltrb[3];

                Object obj;
                obj.rect.x = x0;
                obj.rect.y = y0;
                obj.rect.width = x1 - x0;
                obj.rect.height = y1 - y0;
                obj.label = label;
                obj.prob = score;

                objects.push_back(obj);
            }
        }
    }
}



int NanoDet::detect(const cv::Mat& bgr, std::vector<Object>& objects)
{
    int width = bgr.cols;
    int height = bgr.rows;

    // pad to multiple of 32
    int w = width;
    int h = height;
    float scale = 1.f;
    if (w > h)
    {
        scale = (float)target_size / w;
        w = target_size;
        h = h * scale;
    }
    else
    {
        scale = (float)target_size / h;
        h = target_size;
        w = w * scale;
    }

    ncnn::Mat in = ncnn::Mat::from_pixels_resize(bgr.data, ncnn::Mat::PIXEL_BGR, width, height, w, h);

    // pad to target_size rectangle
    int wpad = (w + 31) / 32 * 32 - w;
    int hpad = (h + 31) / 32 * 32 - h;
    ncnn::Mat in_pad;
    ncnn::copy_make_border(in, in_pad, hpad / 2, hpad - hpad / 2, wpad / 2, wpad - wpad / 2, ncnn::BORDER_CONSTANT, 0.f);

    const float mean_vals[3] = { 103.53f, 116.28f, 123.675f };
    const float norm_vals[3] = { 0.017429f, 0.017507f, 0.017125f };
    in_pad.substract_mean_normalize(mean_vals, norm_vals);

    ncnn::Extractor ex = this->Net->create_extractor();
    ex.input("in0", in_pad);

    std::vector<Object> proposals;

    // stride 8
    {
        ncnn::Mat pred;
        ex.extract("150", pred);
        std::vector<Object> objects8;
        generate_proposals(pred, 8, in_pad, this->prob_threshold, objects8);
        proposals.insert(proposals.end(), objects8.begin(), objects8.end());
    }

    // stride 16
    {
        ncnn::Mat pred;
        ex.extract("160", pred);
        std::vector<Object> objects16;
        generate_proposals(pred, 16, in_pad, this->prob_threshold, objects16);
        proposals.insert(proposals.end(), objects16.begin(), objects16.end());
    }

    // stride 32
    {
        ncnn::Mat pred;
        ex.extract("170", pred);
        std::vector<Object> objects32;
        generate_proposals(pred, 32, in_pad, this->prob_threshold, objects32);
        proposals.insert(proposals.end(), objects32.begin(), objects32.end());
    }

    // sort all proposals by score from highest to lowest
    qsort_descent_inplace(proposals);

    // apply nms with nms_threshold
    std::vector<int> picked;
    nms_sorted_bboxes(proposals, picked, this->nms_threshold);

    int count = picked.size();
    float x_offset = 4 * (width / (float)target_size);
    float y_offset = 4 * (height / (float)target_size);
    if (width > height) y_offset = y_offset * (width / (float)height);
    if (height > width) x_offset = x_offset * (height / (float)width);

    objects.resize(count);
    for (int i = 0; i < count; i++)
    {
        objects[i] = proposals[picked[i]];

        // adjust offset to original unpadded
        float x0 = (objects[i].rect.x - (wpad / 2)) / scale;
        float y0 = (objects[i].rect.y - (hpad / 2)) / scale;
        float x1 = (objects[i].rect.x + objects[i].rect.width - (wpad / 2)) / scale;
        float y1 = (objects[i].rect.y + objects[i].rect.height - (hpad / 2)) / scale;

        // clip
        x0 = std::max(std::min(x0, (float)(width - 1)), 0.f);
        y0 = std::max(std::min(y0, (float)(height - 1)), 0.f);
        x1 = std::max(std::min(x1, (float)(width - 1)), 0.f);
        y1 = std::max(std::min(y1, (float)(height - 1)), 0.f);
        objects[i].rect.x = x0 + x_offset;
        objects[i].rect.y = y0 + y_offset;
        objects[i].rect.width = x1 - x0;
        objects[i].rect.height = y1 - y0;
    }

    return 0;
}

void NanoDet::draw_objects(const cv::Mat& input_image, cv::Mat& output_image, const std::vector<Object>& objects)
{
    static const char* class_names[] = {
        "0", "LP"
    };

    // Clone the input image to the output image
    output_image = input_image.clone();

    for (size_t i = 0; i < objects.size(); i++)
    {
        const Object& obj = objects[i];
        cv::rectangle(output_image, obj.rect, cv::Scalar(255, 0, 0));
    }
}

void NanoDet::extract_object_clips_clone(const cv::Mat& input_image, const std::vector<Object>& objects, std::vector<cv::Mat>& object_clips)
{
    for (const auto& obj : objects)
    {
        // Ensure the bounding box is within the image bounds
        int x = std::max(0, static_cast<int>(obj.rect.x));
        int y = std::max(0, static_cast<int>(obj.rect.y));
        int width = std::min(static_cast<int>(obj.rect.width), input_image.cols - x);
        int height = std::min(static_cast<int>(obj.rect.height), input_image.rows - y);

        // Extract the region of interest (ROI) from the input image
        cv::Rect roi(x, y, width, height);
        cv::Mat clip = input_image(roi).clone();

        // Add the clip to the vector
        object_clips.push_back(clip);
    }
}
void NanoDet::extract_object_clips_reference(const cv::Mat& input_image, const std::vector<Object>& objects, std::vector<cv::Mat>& object_clips)
{
    for (const auto& obj : objects)
    {
        // Ensure the bounding box is within the image bounds
        int x = std::max(0, static_cast<int>(obj.rect.x));
        int y = std::max(0, static_cast<int>(obj.rect.y));
        int width = std::min(static_cast<int>(obj.rect.width), input_image.cols - x);
        int height = std::min(static_cast<int>(obj.rect.height), input_image.rows - y);

        // Extract the region of interest (ROI) from the input image
        cv::Rect roi(x, y, width, height);
        cv::Mat clip = input_image(roi);

        // Add the clip to the vector
        object_clips.push_back(clip);
    }
}

void NanoDet::extract_and_resize_object_clips(const cv::Mat& input_image, const std::vector<Object>& objects, std::vector<cv::Mat>& object_clips, const cv::Size& target_size)
{


    for (const auto& obj : objects)
    {
        // Ensure the bounding box is within the image bounds
        int x = std::max(0, static_cast<int>(obj.rect.x));
        int y = std::max(0, static_cast<int>(obj.rect.y));
        int width = std::min(static_cast<int>(obj.rect.width), input_image.cols - x);
        int height = std::min(static_cast<int>(obj.rect.height), input_image.rows - y);

        // Extract the region of interest (ROI) from the input image
        cv::Rect roi(x, y, width, height);
        cv::Mat clip = input_image(roi);

        // Resize the clip to the target size
        cv::Mat resized_clip;
        cv::resize(clip, resized_clip, target_size);

        // Add the resized clip to the vector
        object_clips.push_back(resized_clip);
    }
}