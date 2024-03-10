# Setup hook for pytest
echo "Sourcing pytest-check-hook"

declare -ar disabledTests
declare -a disabledTestPaths

function _concatSep {
    local result
    local sep="$1"
    local -n arr=$2
    for index in ${!arr[*]}; do
        if [ $index -eq 0 ]; then
            result="${arr[index]}"
        else
            result+=" $sep ${arr[index]}"
        fi
    done
    echo "$result"
}

function _pytestComputeDisabledTestsString () {
    declare -a tests
    local tests=($1)
    local prefix="not "
    prefixed=( "${tests[@]/#/$prefix}" )
    result=$(_concatSep "and" prefixed)
    echo "$result"
}

function pytestCheckPhase() {
    echo "Executing pytestCheckPhase"
    runHook preCheck

    # Compose arguments
    # args=" -m pytest"
    # Invoke pytest under coverage.py so that coverage data is generated:
    # args=" -m coverage run -m pytest"
    # Use --data-file to tell coverage.py to write data to /tmp/coverage.$pname.dat
    # so we can access it later ($pname is the package name we're currently building):
    args=" -m coverage run --data-file=/tmp/coverage.$pname.dat -m pytest"
    # TODO:
    # * Also configure coverage.py with `dynamic_context = test_function`
    # * Once https://github.com/nedbat/coveragepy/issues/780 is implemented,
    #   configure coverage.py to collect function-level coverage (if it does not now
    #   add this dimension to the line-level coverage data by default).
    if [ -n "$disabledTests" ]; then
        disabledTestsString=$(_pytestComputeDisabledTestsString "${disabledTests[@]}")
      args+=" -k \""$disabledTestsString"\""
    fi

    if [ -n "${disabledTestPaths-}" ]; then
        eval "disabledTestPaths=($disabledTestPaths)"
    fi

    for path in ${disabledTestPaths[@]}; do
      if [ ! -e "$path" ]; then
        echo "Disabled tests path \"$path\" does not exist. Aborting"
        exit 1
      fi
      args+=" --ignore=\"$path\""
    done
    args+=" ${pytestFlagsArray[@]}"
    # eval "@pythonCheckInterpreter@ $args"
    # Append "|| true" to the above so that if running the tests under coverage.py
    # causes them to fail, it won't fail the entire build. Failure can occur for a
    # variety of reasons, none of which are worth failing the build over.
    # (E.g. If the Python project includes its own coverage.py configuration,
    # coverage.py will pick it up (which is typically a good thing). But if the
    # config tells coverage.py to use a plugin that the Nixpkgs maintainer has not
    # added to this Nix package's test dependencies (rightfully, since Nix does not
    # normally run coverage at test time), then coverage.py will fail due to being
    # unable to import the plugin.) In any case, since we're hijacking the build for
    # our own purposes rather than to produce artifacts for downstream consumption,
    # it's better to continue making progress with this (and any other) builds we're
    # in the middle of running rather than immediately aborting all of them.
    eval "@pythonCheckInterpreter@ $args || true"

    runHook postCheck
    echo "Finished executing pytestCheckPhase"
}

if [ -z "${dontUsePytestCheck-}" ] && [ -z "${installCheckPhase-}" ]; then
    echo "Using pytestCheckPhase"
    preDistPhases+=" pytestCheckPhase"

    # It's almost always the case that setuptoolsCheckPhase should not be ran
    # when the pytestCheckHook is being ran
    if [ -z "${useSetuptoolsCheck-}" ]; then
        dontUseSetuptoolsCheck=1

        # Remove command if already injected into preDistPhases
        if [[ "$preDistPhases" =~ "setuptoolsCheckPhase" ]]; then
            echo "Removing setuptoolsCheckPhase"
            preDistPhases=${preDistPhases/setuptoolsCheckPhase/}
        fi
    fi
fi
