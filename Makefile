# MPC X (ARMv7 hard-float) build and desktop smoke-test targets.
ARM_CXX ?= arm-linux-gnueabihf-g++
ARM_CXXFLAGS ?= -O2 -fPIC -fvisibility=hidden -std=c++11 -Wall -Wextra -march=armv7-a -mthumb -mfpu=vfpv3-d16 -mfloat-abi=hard
HOST_CXX ?= g++
HOST_CXXFLAGS ?= -O2 -fPIC -fvisibility=hidden -std=c++11 -Wall -Wextra
HOST_SAMPLE_DIR ?= $(CURDIR)/Samples
TARGET = payload/vst/roland_mv.so

.PHONY: all arm host-test host-smoke validate clean package test-state
all: arm
arm: $(TARGET)
$(TARGET): src/roland_mv_vst2.cpp
	mkdir -p payload/vst
	$(ARM_CXX) $(ARM_CXXFLAGS) -shared -o $@ $<

host-test: build/roland_mv_host_test.so
build/roland_mv_host_test.so: src/roland_mv_vst2.cpp
	mkdir -p build
	$(HOST_CXX) $(HOST_CXXFLAGS) -DROLAND_MV_SAMPLE_DIR=\"$(HOST_SAMPLE_DIR)\" -shared -o $@ $<

host-smoke: host-test
	$(HOST_CXX) -O2 -std=c++11 -Wall -Wextra -o build/vst_host_smoke tests/vst_host_smoke.cpp -ldl
	./build/vst_host_smoke ./build/roland_mv_host_test.so

validate:
	python3 tools/validate_samples.py

package: arm
	sh tools/make_release.sh $(TARGET) build/release

clean:
	rm -rf $(TARGET) build/roland_mv_host_test.so build/vst_host_smoke build/release
	rm -rf build/package

test-skin:
	python3 tools/build_skin.py
	python3 tests/test_skin.py

test-install: host-test
	sh tests/test_install.sh

test-params: host-test
	g++ -O2 -std=c++11 -Wall -Wextra -o build/param_test tests/param_test.cpp -ldl
	./build/param_test ./build/roland_mv_host_test.so

host-smoke-mvff: host-test
	mkdir -p build/mvff_only && cp tests/fixtures/synthetic_kit.MV0 build/mvff_only/kit.MV0
	$(HOST_CXX) $(HOST_CXXFLAGS) -DROLAND_MV_SAMPLE_DIR=\"$(CURDIR)/build/mvff_only\" -shared -o build/mv_native.so src/roland_mv_vst2.cpp
	$(HOST_CXX) -O2 -std=c++11 -o build/vst_host_smoke tests/vst_host_smoke.cpp -ldl
	./build/vst_host_smoke ./build/mv_native.so

test-decode:
	python3 tests/make_fixture.py build/fixture.MV0
	python3 tools/mvff_decode.py build/fixture.MV0 build/fixture_out
	python3 tests/test_decode.py


test-state: host-test
	$(HOST_CXX) -O2 -std=c++11 -Wall -Wextra -o build/state_test tests/state_test.cpp -ldl
	./build/state_test ./build/roland_mv_host_test.so

.PHONY: test-synth-mode
test-synth-mode:
	mkdir -p build/synth_fixture/Patches
	python3 tests/make_fixture.py build/synth_fixture/Patches/fixture.MV0
	$(HOST_CXX) $(HOST_CXXFLAGS) -DROLAND_MV_SAMPLE_DIR=\"$(CURDIR)/build/synth_fixture\" -shared -o build/roland_mv_synth_test.so src/roland_mv_vst2.cpp
	$(HOST_CXX) -O2 -std=c++11 -Wall -Wextra -o build/synth_mode_test tests/synth_mode_test.cpp -ldl
	./build/synth_mode_test ./build/roland_mv_synth_test.so

.PHONY: test-patch-stage
test-patch-stage:
	python3 tests/test_prepare_factory_patches.py
