FROM node:lts-alpine
COPY qb11.zip .
COPY SNUGGLE.BAS .
WORKDIR /
RUN apk -U add zip
RUN zip -ur qb11.zip SNUGGLE.BAS
RUN npx create-dosbox snuggle qb11.zip
WORKDIR /snuggle/
RUN npm install
EXPOSE 8080
CMD [ "npm", "start" ]