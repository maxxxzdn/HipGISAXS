/**
 *  Project:
 *
 *  File: objective_func_hipgisaxs.hpp
 *  Created: Feb 02, 2014
 *  Modified: Mon 17 Mar 2014 04:05:03 PM PDT
 *
 *  Author: Abhinav Sarje <asarje@lbl.gov>
 */

#ifndef __OBJECTIVE_FUNC_HIPGISAXS_HPP__
#define __OBJECTIVE_FUNC_HIPGISAXS_HPP__

#include <analyzer/objective_func.hpp>
#include <hipgisaxs.hpp>

namespace hig {

	class HipGISAXSObjectiveFunction : public ObjectiveFunction {
		private:
			HipGISAXS hipgisaxs_;		// the hipgisaxs object
			unsigned int n_par_;		// nqy
			unsigned int n_ver_;		// nqz

		public:
			HipGISAXSObjectiveFunction(int, char**, DistanceMeasure*);
			HipGISAXSObjectiveFunction(int, char**, std::string);
			~HipGISAXSObjectiveFunction();

			bool set_distance_measure(DistanceMeasure*);
			bool set_reference_data(int);
			bool set_reference_data(char*) { }
			float_vec_t operator()(const float_vec_t&);

			int num_fit_params() const { return hipgisaxs_.num_fit_params(); }
			unsigned int n_par() const { return n_par_; }
			unsigned int n_ver() const { return n_ver_; }
			unsigned int data_size() const { return n_par_ * n_ver_; }
			std::vector <std::string> fit_param_keys() const { return hipgisaxs_.fit_param_keys(); }
			std::vector <float_pair_t> fit_param_limits() const { return hipgisaxs_.fit_param_limits(); }
			float_vec_t fit_param_step_values() const { return hipgisaxs_.fit_param_step_values(); }
			float_vec_t fit_param_init_values() const { return hipgisaxs_.fit_param_init_values(); }

			#ifdef USE_MPI
				woo::MultiNode* multi_node_comm() { return hipgisaxs_.multi_node_comm(); }
			#endif

			// for testing
			bool simulate_and_set_ref(const float_vec_t&);
	}; // class HipGISAXSObjectiveFunction

} // namespace hig

#endif // __OBJECTIVE_FUNC_HIPGISAXS_HPP__
