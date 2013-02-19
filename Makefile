##
# $Id: Makefile 35 2012-08-09 18:29:50Z asarje $
#
# Project: HipGISAXS
#
# File: Makefile
# Created: June 5, 2012
# Modified: Jul 11, 2012
#
# Author: Abhinav Sarje <asarje@lbl.gov>
##

USE_ANA_GPU = y

## base directories
BOOST_DIR = /usr/local/boost_1_49_0
MPI_DIR = /usr/local/openmpi-1.6
CUDA_DIR = /usr/local/cuda-5.0
HDF5_DIR = /usr/local/hdf5-1.8.9
Z_DIR = /usr/local/zlib-1.2.7
SZ_DIR = /usr/local/szip-2.1
TIFF_LIB_DIR = /usr/local/lib
#PARI_DIR = /usr/local/pari-2.5.2

## compilers
CXX = $(MPI_DIR)/bin/mpicxx	#g++
H5CC = $(HDF5_DIR)/bin/h5pcc
NVCC = $(CUDA_DIR)/bin/nvcc #-ccbin /usr/local/gcc-4.6.3/bin

## compiler flags
CXX_FLAGS = -std=c++0x -Wall -Wextra -lgsl -lgslcblas -lm#-v
## gnu c++ compilers >= 4.3 support -std=c++0x [requirement for hipgisaxs 4.3.x <= g++ <= 4.6.x]
## gnu c++ compilers >= 4.7 also support -std=c++11, but they are not supported by cuda

## boost
BOOST_INCL = -I $(BOOST_DIR)
BOOST_LIBS = -L $(BOOST_DIR)/lib -lboost_system -lboost_filesystem -lboost_timer -lboost_chrono

## parallel hdf5
HDF5_INCL = -I$(HDF5_DIR)/include -I$(SZ_DIR)/include -I$(Z_DIR)/include
HDF5_LIBS = -L$(SZ_DIR)/lib -L$(Z_DIR)/lib -L$(HDF5_DIR)/lib -lhdf5 -lz -lsz -lm
HDF5_FLAGS = -Wl,-rpath -Wl,$(HDF5_DIR)/lib
HDF5_FLAGS += -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -D_POSIX_SOURCE -D_BSD_SOURCE

## mpi (openmpi)
MPI_INCL = -I $(MPI_DIR)/include
MPI_LIBS = -L $(MPI_DIR)/lib -lmpi_cxx -lmpi

## cuda
CUDA_INCL = -I$(CUDA_DIR)/include
CUDA_LIBS = -L$(CUDA_DIR)/lib64 -lcudart -lcufft
NVCC_FLAGS = -Xcompiler -fPIC -Xcompiler -fopenmp -m 64
NVCC_FLAGS += -gencode arch=compute_20,code=sm_20
NVCC_FLAGS += -gencode=arch=compute_20,code=compute_20
NVCC_FLAGS += -gencode arch=compute_20,code=sm_21
NVCC_FLAGS += -gencode arch=compute_30,code=sm_30
NVCC_FLAGS += -gencode arch=compute_35,code=sm_35
#NVCC_FLAGS += -Xptxas -v -Xcompiler -v -Xlinker -v --ptxas-options="-v"
NVCC_FLAGS += #-G #-DFINDBLOCK #-DAXIS_ROT
NVLIB_FLAGS = -Xlinker -lgomp
NVLIB_FLAGS += -Wl,-rpath -Wl,$(CUDA_DIR)/lib64

## libtiff
TIFF_LIBS = -L $(TIFF_LIB_DIR) -ltiff

## pari
#PARI_INCL = -I $(PARI_DIR)/include
#PARI_LIBS = -L $(PARI_DIR)/lib
#PARI_LIB_FLAGS = -Wl,-rpath -Wl,$(PARI_DIR)/lib -lpari

## miscellaneous
MISC_INCL =
MISC_FLAGS = -DGPUR -DKERNEL2
MISC_FLAGS += #-DREDUCTION2 #-DAXIS_ROT
ifeq ($(USE_ANA_GPU), y)
MISC_FLAGS += -DFF_ANA_GPU
endif

## choose optimization levels, debug flags, gprof flag, etc
#OPT_FLAGS = -g -DDEBUG #-v #-pg
OPT_FLAGS = -O3 -DNDEBUG #-v

## choose single or double precision here
PREC_FLAG =			# leave empty for single precision
#PREC_FLAG = -DDOUBLEP	# define this for double precision


## all includes
ALL_INCL = $(MPI_INCL) $(CUDA_INCL) $(BOOST_INCL) $(HDF5_INCL) $(MISC_INCL) #$(PARI_INCL)

## all libraries
ALL_LIBS = $(BOOST_LIBS) $(MPI_LIBS) $(NVLIB_FLAGS) $(CUDA_LIBS) $(HDF5_LIBS) $(TIFF_LIBS) #\
		   $(PARI_LIBS) $(PARI_LIB_FLAGS)


PREFIX = $(PWD)
BINARY_SIM = hipgisaxs
BINARY_FIT = hipgisaxs-fit
BIN_DIR = $(PREFIX)/bin
OBJ_DIR = $(PREFIX)/obj
SRC_DIR = $(PREFIX)/src

## all objects
OBJECTS_MAIN = reduction.o ff_num_gpu.o utilities.o numeric_utils.o compute_params.o hig_input.o \
		  image.o inst_detector.o inst_scattering.o layer.o qgrid.o read_oo_input.o sf.o \
		  ff_ana.o ff_num.o ff.o shape.o structure.o object2hdf5.o hipgisaxs_main.o ff_ana_gpu.o \
		  ff_ana_sphere.o ff_ana_box.o ff_ana_cylinder.o ff_ana_hcylinder.o ff_ana_prism3x.o \
		  ff_ana_prism6.o ff_ana_prism.o ff_ana_pyramid.o ff_ana_rand_cylinder.o \
		  ff_ana_sawtooth_down.o ff_ana_sawtooth_up.o ff_ana_trunc_cone.o ff_ana_trunc_pyramid.o \
		  ff_ana_sphere_gpu.o \
		  fitting_steepest_descent.o

OBJECTS_SIM = $(OBJECTS_MAIN) hipgisaxs_sim.o

OBJECTS_FIT = $(OBJECTS_MAIN) hipgisaxs_fit.o

## the main binary
OBJ_BIN_SIM = $(patsubst %,$(OBJ_DIR)/%,$(OBJECTS_SIM))

OBJ_BIN_FIT = $(patsubst %,$(OBJ_DIR)/%,$(OBJECTS_FIT))

$(BINARY_SIM): $(OBJ_BIN_SIM)
	$(CXX) -o $(BIN_DIR)/$@ $^ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(MISC_FLAGS) $(ALL_LIBS)

$(BINARY_FIT): $(OBJ_BIN_FIT)
	$(CXX) -o $(BIN_DIR)/$@ $^ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(MISC_FLAGS) $(ALL_LIBS)

## cuda compilation
_DEPS_NV = %.cuh
DEPS_NV = $(patsubst %,$(SRC_DIR)/%,$(_DEPS_NV))

#### FIXME: fix all this ...
$(OBJ_DIR)/ff_num_gpu.o: $(SRC_DIR)/ff_num_gpu.cu
	$(NVCC) -c $< -o $@ $(OPT_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS) $(NVCC_FLAGS)

$(OBJ_DIR)/ff_ana_gpu.o: $(SRC_DIR)/ff_ana_gpu.cu
	$(NVCC) -c $< -o $@ $(OPT_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS) $(NVCC_FLAGS)

$(OBJ_DIR)/ff_ana_sphere_gpu.o: $(SRC_DIR)/ff_ana_sphere_gpu.cu
	$(NVCC) -c $< -o $@ $(OPT_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS) $(NVCC_FLAGS)

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cu $(DEPS_NV)
	$(NVCC) -c $< -o $@ $(OPT_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS) $(NVCC_FLAGS)

## hdf5-parallel compilation
_DEPS_HDF = object2hdf5.h
DEPS_HDF = $(patsubst %,$(SRC_DIR)/%,$(_DEPS_HDF))

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c $(DEPS_HDF)
	$(H5CC) -c $< -o $@ $(OPT_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

## c++ compilation
_DEPS_CXX = %.hpp
DEPS_CXX = $(patsubst %,$(SRC_DIR)/%,$(_DEPS_CXX))

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp $(DEPS_CXX)
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

############### FIXME: fix all this ...
$(OBJ_DIR)/ff_ana_box.o: $(SRC_DIR)/ff_ana_box.cpp $(SRC_DIR)/ff_ana.hpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

$(OBJ_DIR)/ff_ana_cylinder.o: $(SRC_DIR)/ff_ana_cylinder.cpp $(SRC_DIR)/ff_ana.hpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

$(OBJ_DIR)/ff_ana_hcylinder.o: $(SRC_DIR)/ff_ana_hcylinder.cpp $(SRC_DIR)/ff_ana.hpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

$(OBJ_DIR)/ff_ana_prism3x.o: $(SRC_DIR)/ff_ana_prism3x.cpp $(SRC_DIR)/ff_ana.hpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

$(OBJ_DIR)/ff_ana_prism6.o: $(SRC_DIR)/ff_ana_prism6.cpp $(SRC_DIR)/ff_ana.hpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

$(OBJ_DIR)/ff_ana_prism.o: $(SRC_DIR)/ff_ana_prism.cpp $(SRC_DIR)/ff_ana.hpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

$(OBJ_DIR)/ff_ana_pyramid.o: $(SRC_DIR)/ff_ana_pyramid.cpp $(SRC_DIR)/ff_ana.hpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

$(OBJ_DIR)/ff_ana_rand_cylinder.o: $(SRC_DIR)/ff_ana_rand_cylinder.cpp $(SRC_DIR)/ff_ana.hpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

$(OBJ_DIR)/ff_ana_sawtooth_down.o: $(SRC_DIR)/ff_ana_sawtooth_down.cpp $(SRC_DIR)/ff_ana.hpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

$(OBJ_DIR)/ff_ana_sawtooth_up.o: $(SRC_DIR)/ff_ana_sawtooth_up.cpp $(SRC_DIR)/ff_ana.hpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

$(OBJ_DIR)/ff_ana_sphere.o: $(SRC_DIR)/ff_ana_sphere.cpp $(SRC_DIR)/ff_ana.hpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

$(OBJ_DIR)/ff_ana_trunc_cone.o: $(SRC_DIR)/ff_ana_trunc_cone.cpp $(SRC_DIR)/ff_ana.hpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

$(OBJ_DIR)/ff_ana_trunc_pyramid.o: $(SRC_DIR)/ff_ana_trunc_pyramid.cpp $(SRC_DIR)/ff_ana.hpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

$(OBJ_DIR)/hipgisaxs_sim.o: $(SRC_DIR)/hipgisaxs_sim.cpp $(SRC_DIR)/hipgisaxs_main.hpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

$(OBJ_DIR)/hipgisaxs_fit.o: $(SRC_DIR)/hipgisaxs_fit.cpp $(SRC_DIR)/hipgisaxs_main.hpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

$(OBJ_DIR)/fitting_steepest_descent.o: $(SRC_DIR)/fitting_steepest_descent.cpp $(SRC_DIR)/hipgisaxs_main.hpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)


## test binaries

OBJECTS_CONV = test_conv.o
test_conv: $(patsubst %,$(OBJ_DIR)/%,$(OBJECTS_CONV))
	$(CXX) -o $(BIN_DIR)/$@ $^ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(MISC_FLAGS) $(ALL_LIBS)
$(OBJ_DIR)/$(OBJECTS_CONV): $(SRC_DIR)/test_conv.cpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

OBJECTS_READ = test_read.o read_oo_input.o hig_input.o utilities.o compute_params.o \
	inst_detector.o inst_scattering.o layer.o shape.o structure.o object2hdf5.o
test_read: $(patsubst %,$(OBJ_DIR)/%,$(OBJECTS_READ))
	$(CXX) -o $(BIN_DIR)/$@ $^ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(MISC_FLAGS) $(ALL_LIBS)
$(OBJ_DIR)/test_read.o: $(SRC_DIR)/test_read.cpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

OBJECTS_FF = test_ff.o ff_num.o qgrid.o qgrid_test_create.o object2hdf5.o structure.o \
	shape.o	inst_scattering.o inst_detector.o layer.o ff_num_gpu.o reduction.o hig_input.o \
	compute_params.o read_oo_input.o utilities.o numeric_utils.o
test_ff: $(patsubst %,$(OBJ_DIR)/%,$(OBJECTS_FF))
	$(CXX) -o $(BIN_DIR)/$@ $^ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(MISC_FLAGS) $(ALL_LIBS)
$(OBJ_DIR)/test_ff.o: $(SRC_DIR)/test_ff.cpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)
$(OBJ_DIR)/qgrid_test_create.o: $(SRC_DIR)/qgrid_test_create.cpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

OBJECTS_IMAGE = test_image.o image.o utilities.o
test_image: $(patsubst %,$(OBJ_DIR)/%,$(OBJECTS_IMAGE))
	$(CXX) -o $(BIN_DIR)/$@ $^ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(MISC_FLAGS) $(ALL_LIBS)
$(OBJ_DIR)/test_image.o: $(SRC_DIR)/test_image.cpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

## misc tools binaries

OBJECTS_GEN_PALETTE = generate_palette.o image.o utilities.o
generate_palette: $(patsubst %,$(OBJ_DIR)/%,$(OBJECTS_GEN_PALETTE))
	$(CXX) -o $(BIN_DIR)/$@ $^ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(MISC_FLAGS) $(ALL_LIBS)
$(OBJ_DIR)/generate_palette.o: $(SRC_DIR)/generate_palette.cpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

OBJECTS_PLOT_FF = plot_ff.o image.o utilities.o
plot_ff: $(patsubst %,$(OBJ_DIR)/%,$(OBJECTS_PLOT_FF))
	$(CXX) -o $(BIN_DIR)/$@ $^ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(MISC_FLAGS) $(ALL_LIBS)
$(OBJ_DIR)/plot_ff.o: $(SRC_DIR)/plot_ff.cpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

OBJECTS_PLOT_GISAXS = plot_gisaxs.o image.o utilities.o
plot_gisaxs: $(patsubst %,$(OBJ_DIR)/%,$(OBJECTS_PLOT_GISAXS))
	$(CXX) -o $(BIN_DIR)/$@ $^ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(MISC_FLAGS) $(ALL_LIBS)
$(OBJ_DIR)/plot_gisaxs.o: $(SRC_DIR)/plot_gisaxs.cpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

OBJECTS_COMBINE_FF = combine_ff.o image.o utilities.o numeric_utils.o
combine_ff: $(patsubst %,$(OBJ_DIR)/%,$(OBJECTS_COMBINE_FF))
	$(CXX) -o $(BIN_DIR)/$@ $^ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(MISC_FLAGS) $(ALL_LIBS)
$(OBJ_DIR)/combine_ff.o: $(SRC_DIR)/combine_ff.cpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

OBJECTS_O2S = object2shape.o object2shape_main.o object2hdf5.o
object2shape: $(patsubst %,$(OBJ_DIR)/%,$(OBJECTS_O2S))
	$(CXX) -o $(BIN_DIR)/$@ $^ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(MISC_FLAGS) $(ALL_LIBS)
$(OBJ_DIR)/object2shape%.o: $(SRC_DIR)/object2shape%.cpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

OBJECTS_S2H = shape2hdf5.o shape2hdf5_main.o object2hdf5.o
shape2hdf5: $(patsubst %,$(OBJ_DIR)/%,$(OBJECTS_S2H))
	$(CXX) -o $(BIN_DIR)/$@ $^ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(MISC_FLAGS) $(ALL_LIBS)
$(OBJ_DIR)/shape2hdf5%.o: $(SRC_DIR)/shape2hdf5%.cpp
	$(CXX) -c $< -o $@ $(OPT_FLAGS) $(CXX_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

OBJECTS_O2H = object2hdf5.o
#object2hdf5: $(patsubst %,$(OBJ_DIR)/%,$(OBJECTS_O2H))
#	$(H5CC) -o $(BIN_DIR)/$@ $^ $(OPT_FLAGS) $(PREC_FLAG) $(MISC_FLAGS) $(ALL_LIBS)
$(OBJ_DIR)/objec2hdf5.o: $(SRC_DIR)/object2hdf5.c
	$(H5CC) -c $< -o $@ $(OPT_FLAGS) $(PREC_FLAG) $(ALL_INCL) $(MISC_FLAGS)

all: hipgisaxs test_conv test_read test_ff test_image object2shape shape2hdf5

.PHONY: clean

clean:
	rm -f $(OBJ_BIN_SIM) $(OBJ_BIN_FIT) $(BIN_DIR)/$(BINARY_SIM) $(BIN_DIR)/$(BINARY_FIT) $(BIN_DIR)/test_conv $(OBJ_DIR)/test_conv.o $(BIN_DIR)/test_read $(OBJ_DIR)/test_read.o $(BIN_DIR)/test_ff $(OBJ_DIR)/test_ff.o $(BIN_DIR)/test_image $(OBJ_DIR)/test_image.o $(OBJ_DIR)/qgrid_test_create.o $(OBJ_DIR)/plot_gisaxs.o $(OBJ_DIR)/plot_ff.o $(OBJ_DIR)/generate_palette.o
