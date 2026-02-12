FROM node:lts-alpine
COPY qb11.zip .
COPY SNUGGLE.BAS .
COPY dosbox.conf .
WORKDIR /
RUN apk -U add zip
RUN zip -ur qb11.zip SNUGGLE.BAS
RUN mkdir -p .jsdos && mv dosbox.conf .jsdos/dosbox.conf && zip -ur qb11.zip .jsdos/dosbox.conf
RUN npx create-dosbox snuggle qb11.zip
WORKDIR /snuggle/
RUN npm install
EXPOSE 8080
CMD [ "npm", "start" ]