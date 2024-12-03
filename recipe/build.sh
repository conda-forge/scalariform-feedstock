#!/usr/bin/env bash

set -o xtrace -o nounset -o pipefail -o errexit

# Declare function for downloading licenses associated with each pom.xml using maven
download_licenses() {
    pom_file=$1
    pom_xml=$(dirname ${pom_file})/pom.xml
    mv ${pom_file} ${pom_xml}
    pushd $(dirname ${pom_xml})
    mvn license:download-licenses -Dgoal=download-licenses
    popd
}

export -f download_licenses

mkdir -p .ivy2
mkdir -p .sbt
mkdir -p ${PREFIX}/libexec/${PKG_NAME}
mkdir -p ${PREFIX}/bin

# Build JAR files with sbt
sbt -sbt-dir $SRC_DIR/.sbt -ivy $SRC_DIR/.ivy2 "project cli" "assembly"
cp cli/target/scala-2.13/cli-assembly-${PKG_VERSION}.jar ${PREFIX}/libexec/${PKG_NAME}/${PKG_NAME}.jar

# Create pom.xml files so maven can be used to download licenses
sbt makePom

# Download licenses and gather them from subdirectories
find -name "*.pom" | xargs -I % bash -c 'download_licenses %'
mkdir -p ${SRC_DIR}/target/generated-resources/licenses
find -type d -name "licenses" | grep generated-resources | grep -v "^./target" | xargs -I % bash -c 'cp %/* ./target/generated-resources/licenses'

# Create bash and batch wrappers
tee ${PREFIX}/bin/scalariform << EOF
#!/bin/sh
exec \${JAVA_HOME}/bin/java -jar "\${CONDA_PREFIX}/libexec/scalariform/scalariform.jar" "\$@"
EOF
chmod +x ${PREFIX}/bin/scalariform

tee ${PREFIX}/bin/scalariform.cmd << EOF
call %JAVA_HOME%\bin\java -jar %CONDA_PREFIX%\libexec\scalariform\scalariform.jar %*
EOF
