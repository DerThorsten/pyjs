#!/bin/bash
set -e

# dir of this script
THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BUILD_PREFIX_DIR=$THIS_DIR/build_prefix
WASM_PREFIX_DIR=$THIS_DIR/debug_prefix
WASM_DEPLOY_PREFIX_DIR=$THIS_DIR/deploy_prefix
EMSDK_DIR=$THIS_DIR/emsdk_install
EMSDK_ABI_VERSION=">=4"
DEPLOYMENT_DIR=$THIS_DIR/deploy

mkdir -p $DEPLOYMENT_DIR

MM=$MAMBA_EXE



if false; then
    rm -rf $BUILD_PREFIX_DIR
    echo "Creating wasm env at $BUILD_PREFIX_DIR"
    $MM create -p $BUILD_PREFIX_DIR \
        -f $THIS_DIR/environment-wasm-build.yml \
        --yes
    exit 0
fi

if false; then
    rm -rf $WASM_PREFIX_DIR
    echo "Creating wasm env at $WASM_PREFIX_DIR"
    $MM create -p $WASM_PREFIX_DIR \
            --platform=emscripten-wasm32 \
            -f $THIS_DIR/environment-wasm.yml \
            --yes
            
fi

export PY_VER=3.14

if true; then
    echo "Building pyjs"    

    rm -rf build
    mkdir -p build
    cd build

    export PREFIX=$WASM_PREFIX_DIR
    export CMAKE_PREFIX_PATH=$PREFIX
    export CMAKE_SYSTEM_PREFIX_PATH=$PREFIX
    emcmake cmake \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ON \
    -DBUILD_RUNTIME_BROWSER=ON \
    -DBUILD_RUNTIME_NODE=OFF \
    -DCMAKE_INSTALL_PREFIX=$PREFIX \
    -DLINK_LIBLZMA=ON \
    -DPYTHON_SITE_PACKAGES=$PREFIX/lib/python${PY_VER}/site-packages \
    -DPython_INCLUDE_DIRS=$PREFIX/include/python${PY_VER} \
    -DPython_LIBRARY=$PREFIX/lib/libpython${PY_VER}.a \
    -DPython_LIBRARIES=$PREFIX/lib/libpython${PY_VER}.a \
    -DPython_Interpreter_FOUND=TRUE \
    -DPython_EXECUTABLE=$BUILD_PREFIX/bin/python${PY_VER} \
    -DPYTHON_MODULE_EXTENSION=.so \
    -DPYTHON_MODULE_DEBUG_POSTFIX="" \
    -DPYTHON_MODULE_EXT_SUFFIX=.so \
    -DPython_FOUND=TRUE \
    ..

    emmake make -j8
    emmake make install
fi


DEPLOYMENT_DIR=$THIS_DIR/deploy
mkdir -p $DEPLOYMENT_DIR

# pack env with empack
if false; then

    cd $THIS_DIR


    echo "Packing wasm env"
    rm -rf $DEPLOYMENT_DIR/pyjs-wasm-env.tar.zst

    
    empack pack env \
        --env-prefix $WASM_DEPLOY_PREFIX_DIR \
        --relocate-prefix "/" \
        --no-use-cache \
        --outdir  $DEPLOYMENT_DIR 

    echo "pack pyjs module"
    empack pack dir \
        --host-dir $THIS_DIR/module/pyjs \
        --mount-dir /lib/python3.13/site-packages/pyjs \
        --outname "pyjsmod.tar.gz" \
        --outdir  $DEPLOYMENT_DIR

    empack pack append \
        --env-meta $DEPLOYMENT_DIR/empack_env_meta.json \
        --tarfile $DEPLOYMENT_DIR/pyjsmod.tar.gz  

fi

# copy pyjs binary to deployment dir
cp $THIS_DIR/build/pyjs_runtime_browser.js $DEPLOYMENT_DIR/pyjs_runtime_browser.js
cp $THIS_DIR/build/pyjs_runtime_browser.wasm $DEPLOYMENT_DIR/pyjs_runtime_browser.wasm
# cp $THIS_DIR/index.html $DEPLOYMENT_DIR/index.html

if false; then
    mkdir -p $THIS_DIR/build/host_work_dir
    cd $THIS_DIR
    BUILD_DIR=$THIS_DIR/build
    
    # run in env with does not contain numpy
    pyjs_code_runner run script \
            browser-main \
            --conda-env     $WASM_DEPLOY_PREFIX_DIR  \
            --mount         $THIS_DIR/tests:/tests \
            --mount         $THIS_DIR/module/pyjs:/lib/python3.13/site-packages/pyjs \
            --script        main.py \
            --work-dir      /tests \
            --host-work-dir  $BUILD_DIR/host_work_dir \
            --headless \
            --no-cache \
            --slow-mo 0 \
            --async-main \
            --pyjs-dir      $BUILD_DIR \

fi



# rm -rf deploy
# mkdir -p deploy
# cd deploy

# jupyter lite build --XeusAddon.prefix=$WASM_PREFIX_DIR