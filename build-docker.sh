sudo docker run --rm -e UID=$(id -u) -e GID=$(id -g) --workdir /project -v "$PWD":/project matspfeiffer/flutter build apk