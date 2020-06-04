#!/bin/bash 

set -x
export AWS_DEFAULT_REGION=((s3_region))
export AWS_ACCESS_KEY_ID=((s3_access_key_id))
export AWS_SECRET_ACCESS_KEY=((s3_secret_access_key))
apt-get update && apt-get install -y python3-pip && pip3 install awscli
export PATH=$PATH:/usr/local/bin

bumped_version="$(cat bumped-version/version)"
export bumped_version
offline_tarball="${deployment_name}-${bumped_version}.tgz"
export offline_tarball

release_names="$(ruby kafka-deployment/ci/tasks/create-offline-release/get-all-release-names.rb)"

function calculate_content_sha1sum(){
    local content_sha1sum
    content_sha1sum=$(find . -type f -print0 | sort -z | xargs -0 sha1sum | sha1sum | awk '{ print $1}')

    echo "$content_sha1sum"
}

get_object_metadata_from_s3() {
    aws s3api head-object --bucket binary-releases-repo-rebels --key "deployments/${deployment_name}/${deployment_name}-${running_version}.tgz"
}

function check_deployment_exist_in_s3() {
   get_object_metadata_from_s3 2>&1 | grep -c '404' != 0
}

upload_tarball_with_metadata() {
    aws s3 cp "${offline_tarball}" s3://binary-releases-repo-rebels/deployments/"${deployment_name}"/ --metadata "{ \"sha1\": \"${new_tarball_content_sha1}\" }"
}

mkdir -p offline-release 
pushd offline-release || exit
    mkdir -p releases stemcell vars_file
    touch vars_file/vars.yml
    
    cp ../ubuntu-xenial/*.tgz stemcell/
    cp ../kafka-deployment/manifest.yml .
    
    for release in $release_names; do
    sha1="$(cat ../${release}-sha1/sha1)"
    echo "${release}_sha1: ${sha1}" >> vars_file/vars.yml
    done 

    for release in $release_names; do
    cp ../"${release}"-compiled-release/*.tgz releases/
    done
    
    new_tarball_content_sha1=$(calculate_content_sha1sum)
    
    tar -cvf "${offline_tarball}" ./*

    running_version=$(cat ../running-version/version)
    
    if [[ $(check_deployment_exist_in_s3) ]]; then 
        cp ../bumped-version/version ../target/
        upload_tarball_with_metadata
    else
        get_object_metadata_from_s3 | jq -r ".Metadata.sha1" > current_tar_content_sha1
    
        echo "new_tarball_content_sha1 - ${new_tarball_content_sha1}"

        if [[ ! -z $(< current_tar_content_sha1 tr -d "[:blank:]") ]]; then
            current_tar_content_sha1_value="$(cat current_tar_content_sha1)"
            
            echo "current_tar_content_sha1_value - ${current_tar_content_sha1_value}"
            if [[ "${new_tarball_content_sha1}" != "${current_tar_content_sha1_value}" ]]; then
                upload_tarball_with_metadata

                cp ../bumped-version/version ../target/
            else
                echo "No change in tarball, so not uploading tarball and not incrementing version."

                cp ../running-version/version ../target/
            fi
        else
            upload_tarball_with_metadata
            cp ../bumped-version/version ../target/
        fi
    fi
    rm -rf releases stemcell
popd || exit