#!/bin/bash
STARTTIME=$(date +%s)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
build_tag=$1
name=player
node=$2
org=$3
export sunbird_content_editor_artifact_url=$4
export sunbird_collection_editor_artifact_url=$5
export sunbird_generic_editor_artifact_url=$6
commit_hash=$(git rev-parse --short HEAD)

cd src/app
rm -rf app_dist/
mkdir app_dist/

# function to run client build
build_client(){
    echo "Building client in background"
    nvm install 12.16.1
    nvm use 12.16.1
    node -v
    npm set progress=false
    cd client
    echo "starting client npm install"
    npm install --production --unsafe-perm # install all prod dep
    echo "completed client npm install"
    npm run download-editors # download editors to assests folder
    echo "completed client npm install"
    npm run build # Angular prod build
    echo "completed client prod build"
    npm run post-build # gzip files, rename index file
    echo "completed client post_build"
}

# function to run server build
build_server(){
    echo "Building server in background"
    echo "copying requied files to app_dist"
    cp -R libs helpers proxy resourcebundles cassandra_migration themes package.json framework.config.js package-lock.json sunbird-plugins routes constants controllers server.js app_dist
    cd app_dist
    nvm install 12.16.1
    nvm use 12.16.1
    node -v
    npm set progress=false
    echo "starting server npm install"
    npm i -g npm@6.13.4
    npm install --production --unsafe-perm
    echo "completed server npm install"
    # node helpers/resourceBundles/build.js # need to be tested
}

build_client & # Put client build in background 
build_server & # Put server build in background 
 
## wait for both build to complete
wait 
echo "Client and Server Build complete"
echo "Copying Client dist to app_dist"
mv dist/index.html dist/index.ejs 
cp -R dist app_dist
cd app_dist
sed -i "/version/a\  \"buildHash\": \"${commit_hash}\"," package.json
echo 'Compressing assets directory'
cd ..
tar -cvf player-dist.tar.gz app_dist
cd ../..

docker build --no-cache --label commitHash=$(git rev-parse --short HEAD) -t ${org}/${name}:${build_tag} .

echo {\"image_name\" : \"${name}\", \"image_tag\" : \"${build_tag}\",\"commit_hash\" : \"${commit_hash}\", \"node_name\" : \"$node\"} > metadata.json

ENDTIME=$(date +%s)
echo "It takes $[$ENDTIME - $STARTTIME] seconds to complete this task..."
