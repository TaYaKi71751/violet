#!/bin/bash

DART_FILES="$(find "${HOME}/.pub-cache" -name 'asset_flare.dart' -type f)"
while IFS= read -r DART_PATH
do
	DART="$(cat "${DART_PATH}" | sed 's/hashValues(/Object.hash(/g')"
	echo "" | tee "${DART_PATH}" > /dev/null
	while IFS= read -r DART_LINE
	do
		echo "${DART_LINE}" >> "${DART_PATH}"
	done < <(printf '%s\n' "${DART}")
done < <(printf '%s\n' "${DART_FILES}")

DART_FILES="$(find "${HOME}/.pub-cache" -name 'image_crop.dart' -type f)"
while IFS= read -r DART_PATH
do
	DART="$(cat "${DART_PATH}" | sed 's/hashValues(/Object.hash(/g')"
	echo "" | tee "${DART_PATH}" > /dev/null
	while IFS= read -r DART_LINE
	do
		echo "${DART_LINE}" >> "${DART_PATH}"
	done < <(printf '%s\n' "${DART}")
done < <(printf '%s\n' "${DART_FILES}")
