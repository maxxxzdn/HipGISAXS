/***
  *  Project:
  *
  *  File: distance_functions.hpp
  *  Created: May 17, 2013
  *
  *  Author: Abhinav Sarje <asarje@lbl.gov>
  */

#ifndef __DISTANCE_FUNCTIONS_HPP__
#define __DISTANCE_FUNCTIONS_HPP__

#include <vector>
#include <cmath>

#include <common/typedefs.hpp>
#include <common/constants.hpp>

/**
 * Distance Functors
 */


// The base class used everywhere
class DistanceMeasure {
  public:
    virtual bool operator()(hig::real_t*& ref, hig::real_t*& data,
                            unsigned int*& mask, unsigned int size,
                            std::vector<hig::real_t>& dist) const = 0;
  //  virtual hig::real_t operator()(hig::real_t*& ref, hig::real_t*& data, unsigned int size) const { }
  protected:

    // L1 norm
    hig::real_t norm_l1(hig::real_t*& arr, unsigned int*& mask, unsigned int size) const {
      hig::real_t sum = 0.0;
      for(unsigned int i = 0; i < size; ++ i) sum += mask[i] * arr[i];
      return sum;
    } // norm_l1()

    // L2 norm
    hig::real_t norm_l2(hig::real_t* arr, unsigned int*& mask, unsigned int size) const {
      hig::real_t sum = 0.0;
      for(unsigned int i = 0; i < size; ++ i) sum += mask[i] * arr[i] * arr[i];
      return sqrt(sum);
    } // norm_l2()

    // element-wise product
    hig::real_t vec_dot(hig::real_t* a, hig::real_t* b, unsigned int*& mask, unsigned int size) const {
      hig::real_t sum = 0.0;
      for(unsigned int i = 0; i < size; ++ i) sum += mask[i] * a[i] * b[i];
      return sum;
    } // vec_dot()

}; // class DistanceMeasure


// sum of absolute differences
class AbsoluteDifferenceError : public DistanceMeasure {
  public:
    AbsoluteDifferenceError() { }
    ~AbsoluteDifferenceError() { }

    bool operator()(hig::real_t*& ref, hig::real_t*& data,
                    unsigned int*& mask, unsigned int size,
                    std::vector<hig::real_t>& dist) const {
      if(ref == NULL || data == NULL) return false;
      double dist_sum = 0.0;
      for(int i = 0; i < size; ++ i) {
        dist_sum += mask[i] * fabs(ref[i] - data[i]);
      } // for
      dist.clear();
      dist.push_back((hig::real_t) dist_sum);
      return true;
    } // operator()
}; // class AbsoluteDifferenceError


// residual vector of differences
class ResidualVector : public DistanceMeasure {
  public:
    ResidualVector() { }
    ~ResidualVector() { }

    bool operator()(hig::real_t*& ref, hig::real_t*& data,
                    unsigned int*& mask, unsigned int size,
                    std::vector<hig::real_t>& dist) const {
      dist.clear();
      for(int i = 0; i < size; ++ i) {
        dist.push_back(mask[i] * (ref[i] - data[i]));
      } // for
      return true;
    } // operator()
}; // class ResidualVector


class RelativeResidualVector : public DistanceMeasure {
  public:
    RelativeResidualVector() { }
    ~RelativeResidualVector() { }

    bool operator()(hig::real_t*& ref, hig::real_t*& data,
                    unsigned int*& mask, unsigned int size,
                    std::vector<hig::real_t>& dist) const {
      if(ref == NULL || data == NULL) return false;
      dist.clear();
      for(int i = 0; i < size; ++ i) {
        dist.push_back(mask[i] * (data[i] - ref[i]) / fabs(ref[i]));
      } // for
      return true;
    } // operator()
}; // class RelativeResidualVector


// sum of squares of absolute differences
class AbsoluteDifferenceSquare : public DistanceMeasure {
  public:
    AbsoluteDifferenceSquare() { }
    ~AbsoluteDifferenceSquare() { }

    bool operator()(hig::real_t*& ref, hig::real_t*& data,
                    unsigned int*& mask, unsigned int size,
                    std::vector<hig::real_t>& dist) const {
      if(ref == NULL || data == NULL || mask == NULL) return false;
      double dist_sum = 0.0;
      for(int i = 0; i < size; ++ i) {
        double temp = mask[i] * fabs(ref[i] - data[i]);
        dist_sum += temp * temp;
      } // for
      dist.clear();
      dist.push_back((hig::real_t) dist_sum);
      return true;
    } // operator()
}; // class AbsoluteDifferenceNorm


// sum of squares of relative absolute differences
class RelativeAbsoluteDifferenceSquare : public DistanceMeasure {
  public:
    RelativeAbsoluteDifferenceSquare() { }
    ~RelativeAbsoluteDifferenceSquare() { }

    bool operator()(hig::real_t*& ref, hig::real_t*& data,
                    unsigned int*& mask, unsigned int size,
                    std::vector<hig::real_t>& dist) const {
      if(ref == NULL || data == NULL) return false;
      double dist_sum = 0.0;
      for(int i = 0; i < size; ++ i) {
        double temp = mask[i] * fabs((ref[i] - data[i]) / ref[i]);
        dist_sum += temp * temp;
      } // for
      dist.clear();
      dist.push_back((hig::real_t) dist_sum);
      return true;
    } // operator()
}; // class RelativeAbsoluteDifferenceSquare


// sum of squares of scaled relative absolute differences
class ScaledRelativeAbsoluteDifferenceSquare : public DistanceMeasure {
  private:
    bool find_minmax(hig::real_t*& arr, unsigned int*& mask, unsigned int size,
                     hig::real_t& arr_min, hig::real_t& arr_max) const {
      arr_min = arr[0]; arr_max = arr[0];
      for(auto i = 0; i < size; ++ i) {
        if(!mask[i]) continue;
        arr_min = std::min(arr_min, arr[i]);
        arr_max = std::max(arr_max, arr[i]);
      } // for
      return true;
    } // find_minmax()

  public:
    ScaledRelativeAbsoluteDifferenceSquare() { }
    ~ScaledRelativeAbsoluteDifferenceSquare() { }

    bool operator()(hig::real_t*& ref, hig::real_t*& dat,
                    unsigned int*& mask, unsigned int size,
                    std::vector<hig::real_t>& dist) const {
      if(ref == NULL || dat == NULL) return false;
      // find min and max of masked ref and data in order to normalize each
      hig::real_t ref_min, ref_max, dat_min, dat_max;
      find_minmax(ref, mask, size, ref_min, ref_max);
      find_minmax(dat, mask, size, dat_min, dat_max);
      hig::real_t ref_range = ref_max - ref_min;
      hig::real_t dat_range = dat_max - dat_min;
      if(ref_range < hig::TINY_) ref_range = 1.0;
      if(dat_range < hig::TINY_) dat_range = 1.0;
      double dist_sum = 0.0;
      for(int i = 0; i < size; ++ i) {
        hig::real_t scaled_ref = (ref[i] - ref_min) / ref_range;
        hig::real_t scaled_dat = (dat[i] - dat_min) / dat_range;
        double temp = mask[i] * fabs(scaled_ref - scaled_dat);
        dist_sum += temp * temp;
      } // for
      //std::cout << "DISTANCE: " << dist_sum << std::endl;
      dist.clear();
      dist.push_back((hig::real_t) dist_sum);
      return true;
    } // operator()
}; // class ScaledRelativeAbsoluteDifferenceSquare


// unit-length normalized/scaled chi2 (with L1-norm)
class UnitLengthNormalizedDifferenceL1Norm : public DistanceMeasure {
  public:
    UnitLengthNormalizedDifferenceL1Norm() { }
    ~UnitLengthNormalizedDifferenceL1Norm() { }

    bool operator()(hig::real_t*& ref, hig::real_t*& dat,
                    unsigned int*& mask, unsigned int size,
                    std::vector<hig::real_t>& dist) const {
      if(ref == NULL || dat == NULL) return false;
      hig::real_t ref_norm = norm_l2(ref, mask, size);
      hig::real_t dat_norm = norm_l2(dat, mask, size);
      double dist_sum = 0.0;
      for(unsigned int i = 0; i < size; ++ i) {
        hig::real_t n_data = dat[i] / dat_norm,
                    n_ref = ref[i] / ref_norm;
        hig::real_t temp = mask[i] * fabs(n_data - n_ref);
        dist_sum += temp;
      } // for
      dist.clear();
      dist.push_back((hig::real_t) dist_sum);
      return true;
    } // operator()
}; // class UnitLengthNormalizedDifferenceL1Norm


// unit-length normalized/scaled chi2 (with L2-norm) -- default
class UnitLengthNormalizedDifferenceSquareNorm : public DistanceMeasure {
  public:
    UnitLengthNormalizedDifferenceSquareNorm() { }
    ~UnitLengthNormalizedDifferenceSquareNorm() { }

    bool operator()(hig::real_t*& ref, hig::real_t*& dat,
                    unsigned int*& mask, unsigned int size,
                    std::vector<hig::real_t>& dist) const {
      if(ref == NULL || dat == NULL) return false;
      hig::real_t ref_norm = norm_l2(ref, mask, size);
      hig::real_t dat_norm = norm_l2(dat, mask, size);
      double dist_sum = 0.0;
      for(unsigned int i = 0; i < size; ++ i) {
        hig::real_t n_data = dat[i] / dat_norm,
                    n_ref = ref[i] / ref_norm;
        hig::real_t temp = mask[i] * (n_data - n_ref);
        dist_sum += temp * temp;
      } // for
      dist.clear();
      //dist.push_back((hig::real_t) dist_sum / (ref_norm * ref_norm));
      dist.push_back((hig::real_t) dist_sum);
      return true;
    } // operator()
}; // class UnitLengthNormalizedDifferenceSquareNorm


// normalized with computed constant (jeff's), with L2-norm
class ConstNormalizedDifferenceL2NormSquare : public DistanceMeasure {
  public:
    ConstNormalizedDifferenceL2NormSquare() { }
    ~ConstNormalizedDifferenceL2NormSquare() { }

    bool operator()(hig::real_t*& ref, hig::real_t*& dat,
                    unsigned int*& mask, unsigned int size,
                    std::vector<hig::real_t>& dist) const {
      if(ref == NULL || dat == NULL) return false;
      hig::real_t ref_norm = norm_l2(ref, mask, size); ref_norm *= ref_norm;
      hig::real_t dot_prod = vec_dot(dat, ref, mask, size);
      hig::real_t c = dot_prod / ref_norm;
      double dist_sum = 0.0;
      for(unsigned int i = 0; i < size; ++ i) {
        hig::real_t n_dat = c * dat[i],
                    n_ref = ref[i];
        hig::real_t temp = mask[i] * fabs(n_ref - n_dat);
        dist_sum += temp * temp;
      } // for
      dist.clear();
      dist.push_back((hig::real_t) dist_sum);
      return true;
    } // operator()
}; // class ConstNormalizedDifferenceL2NormSquare


// sqrt with unit-length normalized/scaled chi2 (with L1-norm)
class SqrtUnitLengthNormalizedDifferenceL1Norm : public DistanceMeasure {
  public:
    SqrtUnitLengthNormalizedDifferenceL1Norm() { }
    ~SqrtUnitLengthNormalizedDifferenceL1Norm() { }

    bool operator()(hig::real_t*& ref, hig::real_t*& dat,
                    unsigned int*& mask, unsigned int size,
                    std::vector<hig::real_t>& dist) const {
      if(ref == NULL || dat == NULL) return false;
      std::vector<hig::real_t> sqrt_ref, sqrt_dat;
      sqrt_ref.resize(size); sqrt_dat.resize(size);
      for(unsigned int i = 0; i < size; ++ i) {
        sqrt_ref[i] = sqrt(ref[i]);
        sqrt_dat[i] = sqrt(dat[i]);
      } // for
      hig::real_t ref_norm = norm_l2(&sqrt_ref[0], mask, size);
      hig::real_t dat_norm = norm_l2(&sqrt_dat[0], mask, size);
      double dist_sum = 0.0;
      for(unsigned int i = 0; i < size; ++ i) {
        hig::real_t n_data = sqrt_dat[i] / dat_norm,
                    n_ref = sqrt_ref[i] / ref_norm;
        hig::real_t temp = mask[i] * fabs(n_data - n_ref);
        dist_sum += temp;
      } // for
      dist.clear();
      dist.push_back((hig::real_t) dist_sum);
      return true;
    } // operator()
}; // class SqrtUnitLengthNormalizedDifferenceL1Norm


// sqrt with unit-length normalized with L2-norm
class SqrtUnitLengthNormalizedDifferenceSquareNorm : public DistanceMeasure {
  public:
    SqrtUnitLengthNormalizedDifferenceSquareNorm() { }
    ~SqrtUnitLengthNormalizedDifferenceSquareNorm() { }

    bool operator()(hig::real_t*& ref, hig::real_t*& dat,
                    unsigned int*& mask, unsigned int size,
                    std::vector<hig::real_t>& dist) const {
      if(ref == NULL || dat == NULL) return false;
      std::vector<hig::real_t> sqrt_ref, sqrt_dat;
      sqrt_ref.resize(size); sqrt_dat.resize(size);
      for(unsigned int i = 0; i < size; ++ i) {
        sqrt_ref[i] = sqrt(ref[i]);
        sqrt_dat[i] = sqrt(dat[i]);
      } // for
      hig::real_t ref_norm = norm_l2(&sqrt_ref[0], mask, size);
      hig::real_t dat_norm = norm_l2(&sqrt_dat[0], mask, size);
      double dist_sum = 0.0;
      for(unsigned int i = 0; i < size; ++ i) {
        hig::real_t n_data = sqrt_dat[i] / dat_norm,
                    n_ref = sqrt_ref[i] / ref_norm;
        hig::real_t temp = mask[i] * (n_data - n_ref);
        dist_sum += temp * temp;
      } // for
      dist.clear();
      dist.push_back((hig::real_t) dist_sum);
      return true;
    } // operator()
}; // class SqrtUnitLengthNormalizedDifferenceSquareNorm


// sqrt with normalized with computed constant (jeff's), with L2-norm
class SqrtConstNormalizedDifferenceL2NormSquare : public DistanceMeasure {
  public:
    SqrtConstNormalizedDifferenceL2NormSquare() { }
    ~SqrtConstNormalizedDifferenceL2NormSquare() { }

    bool operator()(hig::real_t*& ref, hig::real_t*& dat,
                    unsigned int*& mask, unsigned int size,
                    std::vector<hig::real_t>& dist) const {
      if(ref == NULL || dat == NULL) return false;
      std::vector<hig::real_t> sqrt_ref, sqrt_dat;
      sqrt_ref.resize(size); sqrt_dat.resize(size);
      for(unsigned int i = 0; i < size; ++ i) {
        sqrt_ref[i] = sqrt(ref[i]);
        sqrt_dat[i] = sqrt(dat[i]);
      } // for
      hig::real_t ref_norm = norm_l2(&sqrt_ref[0], mask, size); ref_norm *= ref_norm;
      hig::real_t dot_prod = vec_dot(&sqrt_dat[0], &sqrt_ref[0], mask, size);
      hig::real_t c = dot_prod / ref_norm;
      double dist_sum = 0.0;
      for(unsigned int i = 0; i < size; ++ i) {
        hig::real_t n_dat = c * sqrt_dat[i],
                    n_ref = sqrt_ref[i];
        hig::real_t temp = mask[i] * fabs(n_ref - n_dat);
        dist_sum += temp * temp;
      } // for
      dist.clear();
      dist.push_back((hig::real_t) dist_sum);
      return true;
    } // operator()
}; // class SqrtConstNormalizedDifferenceL2NormSquare


// uses unit-length normalization/scaling -- used in pounders
class UnitLengthNormalizedResidualVector : public DistanceMeasure {
  public:
    UnitLengthNormalizedResidualVector() { }
    ~UnitLengthNormalizedResidualVector() { }

    bool operator()(hig::real_t*& ref, hig::real_t*& data,
                    unsigned int*& mask, unsigned int size,
                    std::vector<hig::real_t>& dist) const {
      if(ref == NULL || data == NULL) return false;
      hig::real_t ref_norm = norm_l2(ref, mask, size);
      hig::real_t dat_norm = norm_l2(data, mask, size);
      dist.clear();
      for(unsigned int i = 0; i < size; ++ i) {
        hig::real_t n_data = data[i] / dat_norm,
                    n_ref = ref[i] / ref_norm;
        hig::real_t temp = mask[i] * (n_data - n_ref);
        //temp *= temp;
        //dist.push_back(mask[i] * temp / (ref_norm * ref_norm));
        //dist.push_back(mask[i] * temp / (ref_norm));
        dist.push_back(temp);
      } // for
      return true;
    } // operator()
}; // class UnitLengthNormalizedResidualVector


// normalized sum of squares of absolute differences
class AbsoluteDifferenceSquareNorm : public DistanceMeasure {
  public:
    AbsoluteDifferenceSquareNorm() { }
    ~AbsoluteDifferenceSquareNorm() { }

    bool operator()(hig::real_t*& ref, hig::real_t*& data,
                    unsigned int*& mask, unsigned int size,
                    std::vector<hig::real_t>& dist) const {
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
      dist.push_back((hig::real_t) dist_sum);
      return true;
    } // operator()
}; // class AbsoluteDifferenceNorm


// normalized sum of absolute differences
class AbsoluteDifferenceNorm : public DistanceMeasure {
  public:
    AbsoluteDifferenceNorm() { }
    ~AbsoluteDifferenceNorm() { }

    bool operator()(hig::real_t*& ref, hig::real_t*& data,
                    unsigned int*& mask, unsigned int size,
                    std::vector<hig::real_t>& dist) const {
      if(ref == NULL || data == NULL) return false;
      double dist_sum = 0.0;
      double ref_sum = 0.0;
      for(int i = 0; i < size; ++ i) {
        dist_sum += mask[i] * fabs(ref[i] - data[i]);
        ref_sum += mask[i] * ref[i];
      } // for
      dist_sum /= ref_sum;
      dist.clear();
      dist.push_back((hig::real_t) dist_sum);
      return true;
    } // operator()
}; // class AbsoluteDifferenceNorm


#endif // __DISTANCE_FUNCTIONS_HPP__
