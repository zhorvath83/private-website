# This is a multi-stage Dockerfile 

########################################################## Stage 1
FROM alpine:3.19.1 AS resume-stage
WORKDIR /resume 
COPY ./resume.json .
RUN apk add npm git
RUN npm init -y

# renovate: datasource=github-releases depName=jsonresume/resume-cli
ENV RESUMECLI_VERSION=v3.0.8

RUN npm install resume-cli@${RESUMECLI_VERSION##v} jsonresume-theme-macchiato
# And then we just run Resume CLI
RUN npx resume export /resume/index.html --format html --theme macchiato


########################################################## Stage 2
FROM alpine:3.19.1 AS hugo-stage

# renovate: datasource=github-releases depName=gohugoio/hugo
ENV HUGO_VERSION=v0.125.6

RUN apk add tar curl
RUN echo "Installing hugo version '${HUGO_VERSION##v}' ..." && \
    curl -SsL "https://github.com/gohugoio/hugo/releases/download/${HUGO_VERSION}/hugo_${HUGO_VERSION##v}_Linux-64bit.tar.gz" | \
      tar xz -C /usr/local/bin hugo && \
    chmod 755 /usr/local/bin/hugo
# The source files are copied to /site
COPY . /site
COPY --from=resume-stage /resume/index.html /site/content/resume/index.html
WORKDIR /site
# And then we just run Hugo
RUN /usr/local/bin/hugo --minify


########################################################## Stage 3
FROM nginxinc/nginx-unprivileged:1.26.0-alpine AS final-stage
USER root
RUN apk update && apk add --upgrade apk-tools && apk upgrade --available
WORKDIR /usr/share/nginx/html/
# Clean the default public folder
RUN rm -fr * .??*
# Finally, the "public" folder generated by Hugo is copied into the public folder of nginx
COPY --from=hugo-stage /site/public /usr/share/nginx/html
RUN chown -R nginx /usr/share/nginx/html/

USER nginx
# Listen to required port(s)
EXPOSE 8080
