#!/bin/bash

set -o errexit -o pipefail -o nounset -o xtrace

${PIP} install . --user
export PATH=$HOME/.local/bin:$PATH

dir=test-$TRAVIS_RUST_VERSION-$PIP
echo "Running in $dir"
cp -r test "$dir"
cd "$dir"

# an invalid rust version does nothing
travis-cargo --only xx$TRAVIS_RUST_VERSION build
test ! -d target

# noisy builds by default
travis-cargo build | grep Running
cargo clean
# a quiet build doesn't print anything
! travis-cargo -q build | grep Running

# arguments
travis-cargo test -- --features 'remove-failing'
if [ "$TRAVIS_RUST_VERSION" = nightly ]; then
    travis-cargo test -- --features 'remove-failing' | grep default_unstable_test
    TRAVIS_CARGO_NIGHTLY_FEATURE="custom-unstable" \
        travis-cargo test -- --features 'remove-failing' | grep custom_unstable_test

    travis-cargo bench -- --features 'remove-failing' | grep unstable_benchmark
else
    travis-cargo bench -- --features 'remove-failing' | grep skipping
fi

# run documentation build
travis-cargo doc
travis-cargo doc-upload

travis-cargo coverage -m target/coverage -- --features 'remove-failing'
# the two source file names should appear somewhere in the coverage
# output
for pattern in "$dir/tests/foo.rs" "$dir/src/lib.rs"; do
    grep "$pattern" target/coverage/kcov-merged/index.json
done

rm -rf kcov
travis-cargo coveralls -- --features 'remove-failing'
