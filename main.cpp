#include <opencv2/opencv.hpp>
#include <iostream>
#include <vector>
#include <cmath>
#include <queue>

using namespace cv;
using namespace std;

double calcEntropy(const Mat& input) {
    Mat gray;
    if (input.channels() > 1) {
        cvtColor(input, gray, COLOR_BGR2GRAY);
    } else {
        gray = input;
    }

    int histSize = 256;
    float range[] = {0, 256};
    const float* histRange = {range};
    Mat hist;
    calcHist(&gray, 1, 0, Mat(), hist, 1, &histSize, &histRange, true, false);

    double total = static_cast<double>(gray.total());
    double entropy = 0.0;
    for (int i = 0; i < 256; ++i) {
        float h = hist.at<float>(i);
        if (h <= 0) continue;
        double p = h / total;
        entropy -= p * log2(p);
    }
    return entropy;
}

Mat addGaussianNoise(const Mat& gray, double stddev = 25.0) {
    Mat gray32f, noise, dst32f, dst;
    gray.convertTo(gray32f, CV_32F);
    noise = Mat(gray32f.size(), gray32f.type());
    randn(noise, 0, stddev);
    dst32f = gray32f + noise;
    min(dst32f, 255, dst32f);
    max(dst32f, 0, dst32f);
    dst32f.convertTo(dst, CV_8U);
    return dst;
}

Mat addSaltPepperNoise(const Mat& gray, double ratio = 0.02) {
    Mat dst = gray.clone();
    RNG rng;
    int n = static_cast<int>(dst.total() * ratio);
    for (int i = 0; i < n; i++) {
        int x = rng.uniform(0, dst.cols);
        int y = rng.uniform(0, dst.rows);
        dst.at<uchar>(y, x) = (rng.uniform(0, 2) == 0) ? 0 : 255;
    }
    return dst;
}

Mat sobelEdge(const Mat& gray) {
    Mat grad_x, grad_y, abs_grad_x, abs_grad_y, grad;
    Sobel(gray, grad_x, CV_16S, 1, 0, 3);
    Sobel(gray, grad_y, CV_16S, 0, 1, 3);
    convertScaleAbs(grad_x, abs_grad_x);
    convertScaleAbs(grad_y, abs_grad_y);
    addWeighted(abs_grad_x, 0.5, abs_grad_y, 0.5, 0, grad);
    return grad;
}

Mat laplacianEdge(const Mat& gray) {
    Mat lap;
    Laplacian(gray, lap, CV_16S, 3);
    convertScaleAbs(lap, lap);
    return lap;
}

Mat overlayEdge(const Mat& src, const Mat& edge, int edgeThreshold = 40) {
    Mat over;
    if (src.channels() == 1) {
        cvtColor(src, over, COLOR_GRAY2BGR);
    } else {
        over = src.clone();
    }

    for (int i = 0; i < over.rows; i++) {
        for (int j = 0; j < over.cols; j++) {
            if (edge.at<uchar>(i, j) > edgeThreshold) {
                over.at<Vec3b>(i, j) = Vec3b(0, 255, 0);
            }
        }
    }
    return over;
}

int iterativeThreshold(const Mat& gray) {
    int T = cvRound(mean(gray)[0]);
    while (true) {
        long long sum1 = 0, sum2 = 0;
        int cnt1 = 0, cnt2 = 0;

        for (int i = 0; i < gray.rows; i++) {
            const uchar* row = gray.ptr<uchar>(i);
            for (int j = 0; j < gray.cols; j++) {
                uchar p = row[j];
                if (p >= T) {
                    sum1 += p;
                    cnt1++;
                } else {
                    sum2 += p;
                    cnt2++;
                }
            }
        }

        if (cnt1 == 0 || cnt2 == 0) {
            return T;
        }

        int m1 = cvRound(static_cast<double>(sum1) / cnt1);
        int m2 = cvRound(static_cast<double>(sum2) / cnt2);
        int T_new = (m1 + m2) / 2;

        if (abs(T_new - T) < 1) {
            return T_new;
        }
        T = T_new;
    }
}

Mat iterativeThresholdColor(const Mat& bgr) {
    vector<Mat> channels;
    split(bgr, channels);
    vector<Mat> binary(3);
    for (int c = 0; c < 3; ++c) {
        int t = iterativeThreshold(channels[c]);
        threshold(channels[c], binary[c], t, 255, THRESH_BINARY);
    }
    Mat merged;
    merge(binary, merged);
    return merged;
}

Mat regionGrowAdaptive(const Mat& gray, Point seed, int thresholdValue, const Mat& limitMask = Mat()) {
    Mat mask = Mat::zeros(gray.size(), CV_8U);
    if (seed.x < 0 || seed.y < 0 || seed.x >= gray.cols || seed.y >= gray.rows) {
        return mask;
    }

    if (!limitMask.empty() && limitMask.at<uchar>(seed) == 0) {
        return mask;
    }

    queue<Point> q;
    q.push(seed);
    mask.at<uchar>(seed) = 255;

    double runningMean = gray.at<uchar>(seed);
    int count = 1;

    const int dx[] = {-1, 1, 0, 0, -1, -1, 1, 1};
    const int dy[] = {0, 0, -1, 1, -1, 1, -1, 1};

    while (!q.empty()) {
        Point p = q.front();
        q.pop();

        for (int d = 0; d < 8; d++) {
            int x = p.x + dx[d];
            int y = p.y + dy[d];
            if (x < 0 || y < 0 || x >= gray.cols || y >= gray.rows) continue;
            if (mask.at<uchar>(y, x) != 0) continue;
            if (!limitMask.empty() && limitMask.at<uchar>(y, x) == 0) continue;

            uchar val = gray.at<uchar>(y, x);
            if (std::fabs(static_cast<double>(val) - runningMean) <= static_cast<double>(thresholdValue)) {
                mask.at<uchar>(y, x) = 255;
                q.push(Point(x, y));
                runningMean = (runningMean * count + val) / (count + 1);
                count++;
            }
        }
    }

    return mask;
}

Mat embossEffect(const Mat& gray) {
    Mat kernel = (Mat_<float>(3, 3) <<
                  -2, -1, 0,
                  -1, 1, 1,
                  0, 1, 2);
    Mat res16, res;
    filter2D(gray, res16, CV_16S, kernel);
    convertScaleAbs(res16, res);
    return res;
}

static Mat largestConnectedComponent(const Mat& binary) {
    Mat labels, stats, centroids;
    int n = connectedComponentsWithStats(binary, labels, stats, centroids, 8, CV_32S);
    if (n <= 1) return Mat::zeros(binary.size(), CV_8U);

    int bestLabel = 1;
    int bestArea = stats.at<int>(1, CC_STAT_AREA);
    for (int i = 2; i < n; ++i) {
        int area = stats.at<int>(i, CC_STAT_AREA);
        if (area > bestArea) {
            bestArea = area;
            bestLabel = i;
        }
    }

    Mat out = Mat::zeros(binary.size(), CV_8U);
    out.setTo(255, labels == bestLabel);
    return out;
}

static Point findSeedNearCenter(const Mat& mask) {
    Point center(mask.cols / 2, mask.rows / 2);
    if (mask.at<uchar>(center) > 0) return center;

    int maxR = min(mask.cols, mask.rows) / 4;
    for (int r = 1; r <= maxR; ++r) {
        for (int dy = -r; dy <= r; ++dy) {
            for (int dx = -r; dx <= r; ++dx) {
                int x = center.x + dx;
                int y = center.y + dy;
                if (x < 0 || y < 0 || x >= mask.cols || y >= mask.rows) continue;
                if (mask.at<uchar>(y, x) > 0) return Point(x, y);
            }
        }
    }
    return center;
}

Mat faceSegmentByRegionGrowing(const Mat& img) {
    Mat gray, ycrcb;
    cvtColor(img, gray, COLOR_BGR2GRAY);
    cvtColor(img, ycrcb, COLOR_BGR2YCrCb);

    Mat skinMask;
    inRange(ycrcb, Scalar(0, 133, 77), Scalar(255, 173, 127), skinMask);

    Mat kernel = getStructuringElement(MORPH_ELLIPSE, Size(7, 7));
    morphologyEx(skinMask, skinMask, MORPH_CLOSE, kernel, Point(-1, -1), 2);
    morphologyEx(skinMask, skinMask, MORPH_OPEN, kernel, Point(-1, -1), 1);

    Point seed = findSeedNearCenter(skinMask);
    Mat rg = regionGrowAdaptive(gray, seed, 20, skinMask);
    Mat faceMask = largestConnectedComponent(rg);

    morphologyEx(faceMask, faceMask, MORPH_CLOSE, kernel, Point(-1, -1), 1);

    Mat face = Mat::zeros(img.size(), img.type());
    img.copyTo(face, faceMask);
    return face;
}

Mat faceSegmentByWatershed(const Mat& img) {
    Mat ycrcb, skinMask;
    cvtColor(img, ycrcb, COLOR_BGR2YCrCb);
    inRange(ycrcb, Scalar(0, 133, 77), Scalar(255, 173, 127), skinMask);

    Mat kernel = getStructuringElement(MORPH_ELLIPSE, Size(5, 5));
    morphologyEx(skinMask, skinMask, MORPH_OPEN, kernel, Point(-1, -1), 1);
    morphologyEx(skinMask, skinMask, MORPH_CLOSE, kernel, Point(-1, -1), 2);

    Mat sureBg;
    dilate(skinMask, sureBg, kernel, Point(-1, -1), 3);

    Mat dist;
    distanceTransform(skinMask, dist, DIST_L2, 3);
    double maxVal = 0;
    minMaxLoc(dist, nullptr, &maxVal);

    Mat sureFg;
    threshold(dist, sureFg, maxVal * 0.35, 255, THRESH_BINARY);
    sureFg.convertTo(sureFg, CV_8U);

    Mat unknown;
    subtract(sureBg, sureFg, unknown);

    Mat markers;
    connectedComponents(sureFg, markers);
    markers = markers + 1;
    markers.setTo(0, unknown == 255);

    Mat wsInput = img.clone();
    watershed(wsInput, markers);

    Mat res = img.clone();
    res.setTo(Scalar(0, 255, 0), markers == -1);
    return res;
}

Mat licensePlateLocate(const Mat& img) {
    Mat hsv, mask;
    cvtColor(img, hsv, COLOR_BGR2HSV);

    inRange(hsv, Scalar(95, 60, 40), Scalar(140, 255, 255), mask);
    Mat kernel = getStructuringElement(MORPH_RECT, Size(5, 3));
    morphologyEx(mask, mask, MORPH_CLOSE, kernel, Point(-1, -1), 2);
    morphologyEx(mask, mask, MORPH_OPEN, kernel, Point(-1, -1), 1);

    vector<vector<Point>> cnts;
    findContours(mask, cnts, RETR_EXTERNAL, CHAIN_APPROX_SIMPLE);

    Mat res = img.clone();
    for (const auto& c : cnts) {
        Rect r = boundingRect(c);
        double area = contourArea(c);
        double ratio = static_cast<double>(r.width) / max(r.height, 1);
        if (area > 700 && ratio > 2.2 && ratio < 6.5 && r.width > 60) {
            rectangle(res, r, Scalar(0, 0, 255), 2);
        }
    }
    return res;
}

double getRoundness(const vector<Point>& contour) {
    double area = contourArea(contour);
    double perimeter = arcLength(contour, true);
    if (perimeter < 1e-6) return 0;
    return 4.0 * CV_PI * area / (perimeter * perimeter);
}

static void cleanMask(Mat& mask, int ksize = 7) {
    Mat kernel = getStructuringElement(MORPH_ELLIPSE, Size(ksize, ksize));
    morphologyEx(mask, mask, MORPH_OPEN, kernel, Point(-1, -1), 1);
    morphologyEx(mask, mask, MORPH_CLOSE, kernel, Point(-1, -1), 2);
}

Mat fruitDetectNatural(const Mat& img) {
    Mat hsv;
    cvtColor(img, hsv, COLOR_BGR2HSV);

    Mat maskBanana, maskWatermelon, maskRed1, maskRed2, maskRed;
    inRange(hsv, Scalar(15, 70, 60), Scalar(40, 255, 255), maskBanana);
    inRange(hsv, Scalar(35, 35, 35), Scalar(90, 255, 255), maskWatermelon);
    inRange(hsv, Scalar(0, 90, 70), Scalar(12, 255, 255), maskRed1);
    inRange(hsv, Scalar(160, 90, 70), Scalar(180, 255, 255), maskRed2);
    maskRed = maskRed1 | maskRed2;

    cleanMask(maskBanana, 7);
    cleanMask(maskWatermelon, 7);
    cleanMask(maskRed, 7);

    Mat res = img.clone();
    vector<vector<Point>> cnts;

    // Watermelon: green + near round
    findContours(maskWatermelon, cnts, RETR_EXTERNAL, CHAIN_APPROX_SIMPLE);
    for (const auto& c : cnts) {
        double area = contourArea(c);
        if (area < 1200) continue;
        Rect r = boundingRect(c);
        double ratio = static_cast<double>(r.width) / max(r.height, 1);
        double round = getRoundness(c);
        if (round > 0.55 && ratio > 0.65 && ratio < 1.45) {
            rectangle(res, r, Scalar(0, 255, 0), 2);
            putText(res, "Watermelon", Point(r.x, max(15, r.y - 6)), FONT_HERSHEY_SIMPLEX, 0.6, Scalar(0, 255, 0), 2);
        }
    }

    // Banana: yellow + elongated + lower roundness
    findContours(maskBanana, cnts, RETR_EXTERNAL, CHAIN_APPROX_SIMPLE);
    for (const auto& c : cnts) {
        double area = contourArea(c);
        if (area < 700) continue;
        Rect r = boundingRect(c);
        double ratio = static_cast<double>(r.width) / max(r.height, 1);
        double round = getRoundness(c);
        if ((ratio > 1.5 || ratio < 0.67) && round < 0.58) {
            rectangle(res, r, Scalar(0, 255, 255), 2);
            putText(res, "Banana", Point(r.x, max(15, r.y - 6)), FONT_HERSHEY_SIMPLEX, 0.6, Scalar(0, 255, 255), 2);
        }
    }

    // Apple/Pomegranate: red + shape discrimination
    findContours(maskRed, cnts, RETR_EXTERNAL, CHAIN_APPROX_SIMPLE);
    for (const auto& c : cnts) {
        double area = contourArea(c);
        if (area < 900) continue;

        Rect r = boundingRect(c);
        double ratio = static_cast<double>(r.width) / max(r.height, 1);
        if (ratio < 0.65 || ratio > 1.5) continue;

        double round = getRoundness(c);
        if (round > 0.78) {
            rectangle(res, r, Scalar(255, 0, 255), 2);
            putText(res, "Apple", Point(r.x, max(15, r.y - 6)), FONT_HERSHEY_SIMPLEX, 0.6, Scalar(255, 0, 255), 2);
        } else if (round > 0.5) {
            rectangle(res, r, Scalar(255, 165, 0), 2);
            putText(res, "Pomegranate", Point(r.x, max(15, r.y - 6)), FONT_HERSHEY_SIMPLEX, 0.6, Scalar(255, 165, 0), 2);
        }
    }

    return res;
}

int main() {
    cout << "========== START ==========" << endl;

    Mat src = imread("h.jpg");
    if (src.empty()) {
        cout << "Load h.jpg failed" << endl;
        return -1;
    }

    Mat gray;
    cvtColor(src, gray, COLOR_BGR2GRAY);

    Mat gauss = addGaussianNoise(gray);
    Mat sp = addSaltPepperNoise(gray);
    imwrite("1_noise_gauss.jpg", gauss);
    imwrite("2_noise_sp.jpg", sp);

    Mat edge_sobel = sobelEdge(gray);
    Mat edge_lap = laplacianEdge(gray);
    imwrite("3_edge_sobel.jpg", edge_sobel);
    imwrite("4_edge_laplacian.jpg", edge_lap);

    Mat overlay = overlayEdge(src, edge_sobel);
    imwrite("5_overlay.jpg", overlay);

    cout << "Original entropy: " << calcEntropy(src) << endl;
    cout << "Overlay entropy: " << calcEntropy(overlay) << endl;

    int th = iterativeThreshold(gray);
    Mat thres_img;
    threshold(gray, thres_img, th, 255, THRESH_BINARY);
    imwrite("6_threshold_gray.jpg", thres_img);

    Mat thres_color = iterativeThresholdColor(src);
    imwrite("6b_threshold_color.jpg", thres_color);

    Mat grow = regionGrowAdaptive(gray, Point(src.cols / 2, src.rows / 2), 18);
    imwrite("7_region_grow.jpg", grow);

    Mat emboss = embossEffect(gray);
    imwrite("8_emboss.jpg", emboss);

    Mat face = imread("face.jpg");
    if (!face.empty()) {
        Mat face1 = faceSegmentByRegionGrowing(face);
        Mat face2 = faceSegmentByWatershed(face);
        imwrite("9_face_grow.jpg", face1);
        imwrite("10_face_watershed.jpg", face2);
    }

    Mat plate = imread("plate.jpg");
    if (!plate.empty()) {
        Mat plate_res = licensePlateLocate(plate);
        imwrite("11_plate.jpg", plate_res);
    }

    Mat fruit = imread("fruit.jpg");
    if (!fruit.empty()) {
        Mat fruit_res = fruitDetectNatural(fruit);
        imwrite("12_fruit.jpg", fruit_res);
    }

    cout << "========== SUCCESS! ALL IMAGES SAVED! ==========" << endl;
    return 0;
}
