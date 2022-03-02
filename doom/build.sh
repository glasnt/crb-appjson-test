DOOM_IMAGE=mattipaksula/http-doom

echo "Copying $DOOM_IMAGE to local project as $IMAGE_URL"
docker pull $DOOM_IMAGE
docker tag $DOOM_IMAGE $IMAGE_URL