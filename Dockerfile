FROM node:lts-alpine
COPY snuggle.zip .
WORKDIR /
RUN npx create-dosbox snuggle snuggle.zip
WORKDIR /snuggle/
RUN npm install
EXPOSE 8080
CMD [ "npm", "start" ]