/*

_________________________________________________________________
Layer (type)                 Output Shapestd::endl;              Param #
=================================================================
conv2d_104 (Conv2D)          (None, 26, 26, 32)        320
_________________________________________________________________
conv2d_105 (Conv2D)          (None, 24, 24, 64)        18496
_________________________________________________________________
max_pooling2d_52 (MaxPooling (None, 12, 12, 64)        0
_________________________________________________________________
dropout_104 (Dropout)        (None, 12, 12, 64)        0
_________________________________________________________________
flatten_52 (Flatten)         (None, 9216)              0
_________________________________________________________________
dense_104 (Dense)            (None, 100)               1013870
_________________________________________________________________
dropout_105 (Dropout)        (None, 100)               0
_________________________________________________________________
dense_105 (Dense)            (None, 10)                1100
=================================================================
Total params: 1,033,796
Trainable params: 1,033,796
Non-trainable params: 0
_________________________________________________________________

Weights

(3, 3, 1, 32)
(32,)
(3, 3, 32, 64)
(64,)
(9216, 100)
(100,)
(100, 10)
(10,)

*/

#include <stdlib.h>
#include <stdio.h>
#include <opencv2/opencv.hpp>
#include <random>
#include <fstream>
#include <iostream>

using namespace std;
using namespace cv;
using namespace cv::ml;

class voiceCNN {
private:

	float **image;

	// weights
	float ****wl1;
	float *bl1;
	float ****wl2;
	float *bl2;
	float **wfc1;
	float *bfc1;
	float **wout;
	float *bout;

	// outputs
	float ***l1; // 26 x 26 x 32 = 208 x 104
	float ***l2; // 24 x 24 x 64 = 192 x 192
	float ***l3; // 12 x 12 x 64 = 96 x 96
	float *fc1; // 100 x 1       = 100 x 1
	float *out; // 10 x 1		 = 10 x 1
	float *outSoft; // 10 x 1    = 10 x 1

public:

	// Annoying callocs
	static void** createArray(int i, int j, size_t size)
	{
		void** r = (void**)calloc(i, sizeof(void*));
		for (int x = 0; x < i; x++) {
			r[x] = (void*)calloc(j, size);
		}
		return r;
	}

	static void*** createArray(int i, int j, int k, size_t size)
	{
		void*** r = (void***)calloc(i, sizeof(void*));
		for (int x = 0; x < i; x++) {
			r[x] = (void**)calloc(j, sizeof(void*));
			for (int y = 0; y < j; y++) {
				r[x][y] = (void*)calloc(k, size);
			}
		}
		return r;
	}

	static void**** createArray(int i, int j, int k, int l, size_t size)
	{
		void**** r = (void****)calloc(i, sizeof(void*));
		for (int x = 0; x < i; x++) {
			r[x] = (void***)calloc(j, sizeof(void*));
			for (int y = 0; y < j; y++) {
				r[x][y] = (void**)calloc(k, sizeof(void*));
				for (int z = 0; z < k; z++) {
					r[x][y][z] = (void*)calloc(l, size);
				}
			}
		}
		return r;
	}

	// Annoying calloc frees
	static void freeArray(int i, int j, void** a)
	{
		for (int x = 0; x < i; x++) {
			free(a[x]);
		}
		free(a);
	}

	static void freeArray(int i, int j, int k, void*** a)
	{
		for (int x = 0; x < i; x++) {
			for (int y = 0; y < j; y++) {
				free(a[x][y]);
			}
			free(a[x]);
		}
		free(a);
	}

	static void freeArray(int i, int j, int k, int l, void**** a)
	{
		for (int x = 0; x < i; x++) {
			for (int y = 0; y < j; y++) {
				for (int z = 0; z < k; z++) {
					free(a[x][y][z]);
				}
				free(a[x][y]);
			}
			free(a[x]);
		}
		free(a);
	}

	inline float relu(float x)
	{
		return fmaxf(0.f, x);
	}

	void getWeights4(ifstream *fin, float ****a, int mi, int mj, int mk, int ml)
	{
		for (int i = 0; i < mi; i++) {
			for (int j = 0; j < mj; j++) {
				for (int k = 0; k < mk; k++) {
					fin->read(reinterpret_cast<char*>(a[i][j][k]), sizeof(float) * ml);
				}
			}
		}
	}

	void getWeights2(ifstream *fin, float **a, int mi, int mj)
	{
		for (int i = 0; i < mi; i++) {
			fin->read(reinterpret_cast<char*>(a[i]), sizeof(float) * mj);
		}
	}

	void getBias(ifstream *fin, float *a, int mi)
	{
		fin->read(reinterpret_cast<char*>(a), sizeof(float) * mi);
	}

	voiceCNN(string path)
	{
		l1 = (float***)createArray(26, 26, 32, sizeof(float));
		l2 = (float***)createArray(24, 24, 64, sizeof(float));
		l3 = (float***)createArray(12, 12, 64, sizeof(float));
		fc1 = (float*)calloc(100, sizeof(float));
		out = (float*)calloc(10, sizeof(float));
		outSoft = (float*)calloc(10, sizeof(float));

		wl1 = (float****)createArray(3, 3, 1, 32, sizeof(float));
		bl1 = (float*)calloc(32, sizeof(float));
		wl2 = (float****)createArray(3, 3, 32, 64, sizeof(float));
		bl2 = (float*)calloc(64, sizeof(float));
		wfc1 = (float**)createArray(9216, 100, sizeof(float));
		bfc1 = (float*)calloc(100, sizeof(float));
		wout = (float**)createArray(100, 10, sizeof(float));
		bout = (float*)calloc(10, sizeof(float));

		ifstream fin(path, ios::binary);
		if (!fin) {
			cout << "error opening file stream" << endl;
			exit(-1);
		}

		getWeights4(&fin, wl1, 3, 3, 1, 32);
		getBias(&fin, bl1, 32);
		getWeights4(&fin, wl2, 3, 3, 32, 64);
		getBias(&fin, bl2, 64);
		getWeights2(&fin, wfc1, 9216, 100);
		getBias(&fin, bfc1, 100);
		getWeights2(&fin, wout, 100, 10);
		getBias(&fin, bout, 10);
	}

	~voiceCNN()
	{
		freeArray(26, 26, 32, (void***)l1);
		freeArray(24, 24, 64, (void***)l2);
		freeArray(12, 12, 64, (void***)l3);
		free(fc1);
		free(out);
		free(outSoft);

		freeArray(3, 3, 1, 32, (void****)wl1);
		freeArray(3, 3, 32, 64, (void****)wl2);
		freeArray(9216, 100, (void**)wfc1);
		freeArray(100, 10, (void**)wout);
		free(bfc1);
		free(bout);
	}

	int forwardProp(float** imageIn)
	{
		image = imageIn;
		// L1, kernel=3x3, stride=1, padding=0
		for (int k = 0; k < 32; k++) {
			for (int i = 0; i < 26; i++) {
				for (int j = 0; j < 26; j++) {
					int i0 = i, i1 = i + 1, i2 = i + 2;
					int j0 = j, j1 = j + 1, j2 = j + 2;

					l1[i][j][k] =
						image[i0][j0] * wl1[0][0][0][k] +
						image[i0][j1] * wl1[0][1][0][k] +
						image[i0][j2] * wl1[0][2][0][k] +
						image[i1][j0] * wl1[1][0][0][k] +
						image[i1][j1] * wl1[1][1][0][k] +
						image[i1][j2] * wl1[1][2][0][k] +
						image[i2][j0] * wl1[2][0][0][k] +
						image[i2][j1] * wl1[2][1][0][k] +
						image[i2][j2] * wl1[2][2][0][k];

					l1[i][j][k] += bl1[k]; // bias
					l1[i][j][k] = relu(l1[i][j][k]); // activation
				}
			}
		}

		

		// L2, kernel=3x3, stride=1, padding=0
		for (int k = 0; k < 64; k++) {
			for (int i = 0; i < 24; i++) {
				for (int j = 0; j < 24; j++) {
					l2[i][j][k] = 0.0f;
					int i0 = i, i1 = i + 1, i2 = i + 2;
					int j0 = j, j1 = j + 1, j2 = j + 2;

					for (int l = 0; l < 32; l++) {
						l2[i][j][k] +=
							l1[i0][j0][l] * wl2[0][0][l][k] +
							l1[i0][j1][l] * wl2[0][1][l][k] +
							l1[i0][j2][l] * wl2[0][2][l][k] +
							l1[i1][j0][l] * wl2[1][0][l][k] +
							l1[i1][j1][l] * wl2[1][1][l][k] +
							l1[i1][j2][l] * wl2[1][2][l][k] +
							l1[i2][j0][l] * wl2[2][0][l][k] +
							l1[i2][j1][l] * wl2[2][1][l][k] +
							l1[i2][j2][l] * wl2[2][2][l][k];
					}

					l2[i][j][k] += bl2[k]; // bias
					l2[i][j][k] = relu(l2[i][j][k]); // activation
				}
			}
		}

		// Max pooling layer, size=2x2, stride=2
		for (int k = 0; k < 64; k++) {
			for (int i = 0; i < 12; i++) {
				for (int j = 0; j < 12; j++) {
					int i0 = i * 2, i1 = i0 + 1;
					int j0 = j * 2, j1 = j0 + 1;

					float m = l2[i0][j0][k];
					m = fmaxf(m, l2[i0][j1][k]);
					m = fmaxf(m, l2[i1][j0][k]);
					m = fmaxf(m, l2[i1][j1][k]);
					l3[i][j][k] = m;
				}
			}
		}

		// fully connected
		for (int k = 0; k < 100; k++)
		{
			fc1[k] = 0.0f;
			for (int l = 0; l < 9216; l++)
			{
				int x = l / 768;
				int y = (l / 12) % 12;
				int z = l % 64;
				fc1[k] += l3[x][y][z] * wfc1[l][k];
			}

			fc1[k] += bfc1[k]; // bias
			fc1[k] = relu(fc1[k]); // activation
		}

		// Output
		for (int k = 0; k < 10; k++)
		{
			out[k] = 0.0f;
			for (int l = 0; l < 100; l++)
			{
				out[k] += fc1[l] * wout[l][k];
			}

			out[k] += bout[k]; // bias
		}

		// Softmax
		for (int i = 0; i < 10; i++) {
			float s = 0.f;
			// Total
			for (int j = 0; j < 10; j++) {
				s += exp(out[j]);
			}
			outSoft[i] = exp(out[i]) / s;
		}

		return (int)(max_element(outSoft, outSoft + 10) - outSoft);
	}
};

#define PATH "D:\\Storage\\Unity\\VoiceRecognitionPython\\voice.bytes"

int main() {

	Mat img;
	img = imread("D:\\Storage\\Datasets\\voice\\images\\extracted\\test\\sit\\sit1-550.png");

	float** imgIn = (float**)voiceCNN::createArray(28, 28, sizeof(float));

	for (int i = 0; i < 28; i++) {
		for (int j = 0; j < 28; j++) {
			// 2 IS RED CHANNEL
			imgIn[i][j] = (img.at<Vec3b>(i, j)[2]) / 255.0f;
			//imgIn[i][j] = (i * j) / 392.0;
		}
	}

	voiceCNN voiceCNNObj = voiceCNN(PATH);
	int label = voiceCNNObj.forwardProp(imgIn);
	std::cout << label << std::endl;

	system("pause");
	return 0;
}