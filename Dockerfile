# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/unrar:latest AS unrar

FROM node:22-alpine AS frontend-builder
RUN mkdir -p /build
RUN git clone --depth 1 --branch provider-subsarr \
    "https://github.com/slimcdk/bazarr.git" /build
WORKDIR /build/frontend
RUN npm ci && npm run build

FROM ghcr.io/linuxserver/baseimage-alpine:3.23

# set version label
ARG BUILD_DATE
ARG VERSION
ARG BAZARR_VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="chbmb"
# hard set UTC in case the user does not define it
ENV TZ="Etc/UTC"

RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache --virtual=build-dependencies \
    build-base \
    cargo \
    libffi-dev \
    libpq-dev \
    libxml2-dev \
    libxslt-dev \
    python3-dev && \
  echo "**** install packages ****" && \
  apk add --no-cache \
    ffmpeg \
    git \
    libxml2 \
    libxslt \
    mediainfo \
    python3 && \
  echo "**** install bazarr ****" && \
  mkdir -p \
    /app/bazarr/bin && \
  git clone --depth 1 --branch provider-subsarr \
    "https://github.com/slimcdk/bazarr.git" \
    /app/bazarr/bin && \
  echo "UpdateMethod=docker\nBranch=provider-subsarr\nPackageVersion=${VERSION}\nPackageAuthor=linuxserver.io" > /app/bazarr/package_info && \
  echo "**** Install requirements ****" && \
  python3 -m venv /lsiopy && \
  pip install -U --no-cache-dir \
    pip \
    wheel && \
  pip install -U --no-cache-dir --find-links https://wheel-index.linuxserver.io/alpine-3.23/ \
    -r /app/bazarr/bin/requirements.txt \
    -r /app/bazarr/bin/postgres-requirements.txt && \
  printf "Linuxserver.io version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version && \
  echo "**** clean up ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    $HOME/.cache \
    $HOME/.cargo \
    /tmp/*

# add built frontend
COPY --from=frontend-builder /build/frontend/build /app/bazarr/bin/frontend/build

# add local files
COPY root/ /

# add unrar
COPY --from=unrar /usr/bin/unrar-alpine /usr/bin/unrar

# ports and volumes
EXPOSE 6767

VOLUME /config
