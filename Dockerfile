FROM node:lts-alpine
WORKDIR /app
RUN apk -U add zip
COPY package.json ./
RUN npm install
COPY qb11.zip SNUGGLE.BAS dosbox.conf ./
RUN zip -ur qb11.zip SNUGGLE.BAS \
 && mkdir -p .jsdos && mv dosbox.conf .jsdos/dosbox.conf \
 && zip -ur qb11.zip .jsdos/dosbox.conf
RUN mkdir -p public \
 && unzip -o qb11.zip -d public/ \
 && rm qb11.zip \
 && find node_modules/js-dos/dist/ -maxdepth 1 -type f -exec cp {} public/ \;
COPY index.html public/index.html
COPY server.js ./
EXPOSE 8080
CMD ["npm", "start"]
