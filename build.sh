DOOM_IMAGE=mattipaksula/http-doom

echo "Copying $DOOM_IMAGE to local project"
docker pull $DOOM_IMAGE

docker tag $DOOM_IMAGE $IMAGE_URL
docker push $IMAGE_URL
echo "Pushed to $IMAGE_URL"