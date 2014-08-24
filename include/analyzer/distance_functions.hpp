/***
  *  Project:
  *
  *  File: distance_functions.hpp
  *  Created: May 17, 2013
  *  Modified: Mon 28 Jul 2014 12:45:19 PM PDT
  *
  *  Author: Abhinav Sarje <asarje@lbl.gov>
  */

#ifndef __DISTANCE_FUNCTIONS_HPP__
#define __DISTANCE_FUNCTIONS_HPP__

#include <vector>
#include <cmath>

/**
 * Distance Functors
 */


// The base class used everywhere
class DistanceMeasure {
	public:
		virtual bool operator()(float*& ref, float*& data, unsigned int*& mask, unsigned int size,
								std::vector<float>& dist) const = 0;
	//	virtual float operator()(float*& ref, float*& data, unsigned int size) const { }
}; // class DistanceMeasure


// sum of absolute differences
class AbsoluteDifferenceError : public DistanceMeasure {
	public:
		AbsoluteDifferenceError() { }
		~AbsoluteDifferenceError() { }

		bool operator()(float*& ref, float*& data, unsigned int*& mask, unsigned int size,
						std::vector<float>& dist) const {
			if(ref == NULL || data == NULL) return false;
			double dist_sum = 0.0;
			for(int i = 0; i < size; ++ i) {
				dist_sum += mask[i] * fabs(ref[i] - data[i]);
			} // for
			dist.clear();
			dist.push_back((float) dist_sum);
			return true;
		} // operator()
}; // class AbsoluteDifferenceError


// vector of differences
class ResidualVector : public DistanceMeasure {
	public:
		ResidualVector() { }
		~ResidualVector() { }

		//std::vector<float> operator()(float*& ref, float*& data, unsigned int size) const {
		bool operator()(float*& ref, float*& data, unsigned int*& mask, unsigned int size,
						std::vector<float>& dist) const {
			dist.clear();
			for(int i = 0; i < size; ++ i) {
				dist.push_back(mask[i] * (ref[i] - data[i]));
			} // for
			return true;
		} // operator()
}; // class ResidualVector


// sum of squares of absolute differences
class AbsoluteDifferenceSquare : public DistanceMeasure {
	public:
		AbsoluteDifferenceSquare() { }
		~AbsoluteDifferenceSquare() { }

		bool operator()(float*& ref, float*& data, unsigned int*& mask, unsigned int size,
						std::vector<float>& dist) const {
			if(ref == NULL || data == NULL || mask == NULL) return false;
			double dist_sum = 0.0;
			for(int i = 0; i < size; ++ i) {
				double temp = mask[i] * fabs(ref[i] - data[i]);
				dist_sum += temp * temp;
			} // for
			dist.clear();
			dist.push_back((float) dist_sum);
			return true;
		} // operator()
}; // class AbsoluteDifferenceNorm


// normalized sum of squares of absolute differences
class AbsoluteDifferenceSquareNorm : public DistanceMeasure {
	public:
		AbsoluteDifferenceSquareNorm() { }
		~AbsoluteDifferenceSquareNorm() { }

		bool operator()(float*& ref, float*& data, unsigned int*& mask, unsigned int size,
						std::vector<float>& dist) const {
			if(ref == NULL || data == NULL) return false;
			double dist_sum = 0.0;
			double ref_sum = 0.0;
			for(int i = 0; i < size; ++ i) {
				double temp = mask[i] * fabs(ref[i] - data[i]);
				dist_sum += temp * temp;
				ref_sum += mask[i] * ref[i] * ref[i];
			} // for
			dist_sum /= ref_sum;
			dist.clear();
			dist.push_back((float) dist_sum);
			return true;
		} // operator()
}; // class AbsoluteDifferenceNorm


// normalized sum of absolute differences
class AbsoluteDifferenceNorm : public DistanceMeasure {
	public:
		AbsoluteDifferenceNorm() { }
		~AbsoluteDifferenceNorm() { }

		bool operator()(float*& ref, float*& data, unsigned int*& mask, unsigned int size,
						std::vector<float>& dist) const {
			if(ref == NULL || data == NULL) return false;
			double dist_sum = 0.0;
			double ref_sum = 0.0;
			for(int i = 0; i < size; ++ i) {
				dist_sum += mask[i] * fabs(ref[i] - data[i]);
				ref_sum += mask[i] * ref[i];
			} // for
			dist_sum /= ref_sum;
			dist.clear();
			dist.push_back((float) dist_sum);
			return true;
		} // operator()
}; // class AbsoluteDifferenceNorm


#endif // __DISTANCE_FUNCTIONS_HPP__