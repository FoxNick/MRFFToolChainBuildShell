#!/bin/zsh

# https://stackoverflow.com/questions/4916492/git-describe-fails-with-fatal-no-names-found-cannot-describe-anything
# git describe --tags --always | awk -F . '{printf "RELEASE_VERSION=%s.%d",$1,$2+1}' | xargs > constants.env
# git describe --tags --always | awk -F - '{printf "RELEASE_VERSION=V1.0-%s",$NF}' | xargs > constants.env

set -e
set -o pipefail

export LIB_NAME=$1
export PLAT=$2

if [[ -n $3 && "$3" == 'true' ]];then
    export DRYRUN=1 
else
    export DRYRUN=
fi

if [[ -n $4 && "$4" == 'true' ]];then
    export VERBOSE=1 
else
    export VERBOSE=
fi

export HOMEBREW_NO_AUTO_UPDATE=1
export RELEASE_DATE=$(TZ=UTC-8 date +'%y%m%d%H%M%S')

if [[ ! -f ./configs/libs/${LIB_NAME}.sh ]]; then
    echo "no such lib config: ./configs/libs/${LIB_NAME}.sh" >&2
    exit 1
fi

RELEASE_VERSION=$(grep GIT_REPO_VERSION= ./configs/libs/${LIB_NAME}.sh | tail -n 1 | awk -F = '{printf "%s",$2}') || true
if [[ -z "$RELEASE_VERSION" ]]; then
    echo "can't read GIT_REPO_VERSION from ./configs/libs/${LIB_NAME}.sh" >&2
    exit 1
fi
export RELEASE_VERSION
export TAG=${LIB_NAME}-${RELEASE_VERSION}-${RELEASE_DATE}
export TITLE="👏👏${LIB_NAME}-${PLAT}-${RELEASE_VERSION}"

ROOT_DIR=$PWD
DIST_DIR=$ROOT_DIR/build/dist
mkdir -p $DIST_DIR

function init_platform
{
    local plat=$1
    echo "---init $plat src--------------------------------------"
    ./main.sh init -p $plat -l ${LIB_NAME}
    
    echo "---generate src log--------------------------------------"
    cd build/src/$plat
    ls | awk -F ' ' '{printf "echo %s\n echo -------------\ngit -C %s log -n 1 | cat\n",$0,$0}' | bash > $DIST_DIR/$plat-compile-log-$RELEASE_VERSION.md
    cd $ROOT_DIR
}

# compile and keep the log, when it fails print the tail of the log,
# otherwise the real error is hidden in an artifact nobody looks at.
function compile_platform
{
    local plat=$1
    local log_file="$DIST_DIR/$plat-compile-log-$RELEASE_VERSION.md"

    if [[ $VERBOSE ]];then
        ./main.sh compile -p $plat -c build -l ${LIB_NAME} 2>&1 | tee -a "$log_file"
    elif ! ./main.sh compile -p $plat -c build -l ${LIB_NAME} >> "$log_file" 2>&1; then
        echo "❌ compile $LIB_NAME for $plat failed, last 100 lines of $log_file:" >&2
        tail -n 100 "$log_file" >&2
        return 1
    fi
}

function compile_ios_platform
{
    echo "---do compile ios libs--------------------------------------"

    compile_platform ios

    cd build/product/ios/universal
    zip -ryq $DIST_DIR/${LIB_NAME}-ios-universal-${RELEASE_VERSION}.zip ./*
    
    cd ../universal-simulator
    zip -ryq $DIST_DIR/${LIB_NAME}-ios-universal-simulator-${RELEASE_VERSION}.zip ./*
    cd $ROOT_DIR
}

function compile_macos_platform
{
    echo "---do compile macos libs--------------------------------------"

    compile_platform macos

    cd build/product/macos/universal
    zip -ryq $DIST_DIR/${LIB_NAME}-macos-universal-${RELEASE_VERSION}.zip ./*
    cd $ROOT_DIR
}

function compile_tvos_platform
{
    echo "---do compile tvos libs--------------------------------------"

    compile_platform tvos

    cd build/product/tvos/universal
    zip -ryq $DIST_DIR/${LIB_NAME}-tvos-universal-${RELEASE_VERSION}.zip ./*
    
    cd ../universal-simulator
    zip -ryq $DIST_DIR/${LIB_NAME}-tvos-universal-simulator-${RELEASE_VERSION}.zip ./*
    cd $ROOT_DIR
}


function compile_android_platform
{
    echo "---do compile android libs--------------------------------------"

    compile_platform android

    cd build/product/android/universal
    zip -ryq $DIST_DIR/${LIB_NAME}-android-universal-${RELEASE_VERSION}.zip ./*
    cd $ROOT_DIR
}

function make_xcfmwk_bundle()
{
    echo "---skip apple xcframework--------------------------------------"
    # echo "---Zip apple xcframework--------------------------------------"
    # cd build/product/xcframework
    # zip -ryq $DIST_DIR/${LIB_NAME}-apple-xcframework-${RELEASE_VERSION}.zip ./*
    # cd $ROOT_DIR
}

function replace_tag()
{
    local file=$1
    local key=$2

    if [[ ! -f "$file" ]]; then
        echo "can't replace $key, no such file: $file" >&2
        return 1
    fi

    # check PRE_COMPILE_TAG_IOS
    if grep -q "$key" "$file"; then
        # replace PRE_COMPILE_TAG_IOS=new_tag
        sed -i "" "s/^export $key=.*/export $key=$TAG/" $file
    else
        # PRE_COMPILE_TAG_IOS not found, append PRE_COMPILE_TAG_IOS
        [ -n "$(tail -c1 "$file")" ] && echo "" >> "$file"
        echo "export $key=$TAG" >> "$file"
    fi
}

function upgrade()
{
    local file="configs/libs/${LIB_NAME}.sh"
    case $PLAT in
        ios)
            replace_tag $file PRE_COMPILE_TAG_IOS
        ;;
        macos)
            replace_tag $file PRE_COMPILE_TAG_MACOS
        ;;
        tvos)
            replace_tag $file PRE_COMPILE_TAG_TVOS
        ;;
        apple)
            replace_tag $file PRE_COMPILE_TAG_IOS
            replace_tag $file PRE_COMPILE_TAG_MACOS
            replace_tag $file PRE_COMPILE_TAG_TVOS
        ;;
        android)
            replace_tag $file PRE_COMPILE_TAG_ANDROID
        ;;
        all)
            replace_tag $file PRE_COMPILE_TAG_IOS
            replace_tag $file PRE_COMPILE_TAG_MACOS
            replace_tag $file PRE_COMPILE_TAG_TVOS
            replace_tag $file PRE_COMPILE_TAG_ANDROID
        ;;
        *)
            echo "can't upgrade tag, unknown plat: [$PLAT]" >&2
            return 1
        ;;
    esac

    git add $file
    git commit -m "upgrade $LIB_NAME to $TAG for $PLAT by cd"
    git pull --rebase
    git push origin
}

function publish()
{
    echo "---Create Release--------------------------------------"
    # a pull_request build is on a detached HEAD, it can't commit tags or release.
    if [[ "$GITHUB_EVENT_NAME" == "pull_request" ]];then
        echo "pull request build: skip upgrade tag and release."
        return
    fi
    if [[ $DRYRUN ]];then
        echo "DRYRUN: gh release create $TAG -t $TITLE $DIST_DIR/*.*"
        return
    fi
    upgrade
    gh release create $TAG --target $(git branch --show-current) -t $TITLE $DIST_DIR/*.* --generate-notes
}

function main()
{
    case $PLAT in
        ios)
            init_platform $PLAT
            compile_ios_platform
            make_xcfmwk_bundle
            publish
        ;;
        macos)
            init_platform $PLAT
            compile_macos_platform
            make_xcfmwk_bundle
            publish
        ;;
        tvos)
            init_platform $PLAT
            compile_tvos_platform
            make_xcfmwk_bundle
            publish
        ;;
        apple)
            init_platform ios
            compile_ios_platform
            init_platform macos
            compile_macos_platform
            init_platform tvos
            compile_tvos_platform
            make_xcfmwk_bundle
            publish
        ;;
        android)
            init_platform $PLAT
            compile_android_platform
            publish
        ;;
        all)
            init_platform ios
            compile_ios_platform
            init_platform macos
            compile_macos_platform
            init_platform tvos
            compile_tvos_platform
            make_xcfmwk_bundle

            init_platform android
            compile_android_platform

            publish
        ;;
        *)
            echo "unknown plat: [$PLAT], use one of [ios|macos|tvos|apple|android|all]" >&2
            exit 1
        ;;
    esac
}

if [[ $LIB_NAME == 'test' ]];then
    echo "test" > $DIST_DIR/test.md
    publish
else
    main
fi