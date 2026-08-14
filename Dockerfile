FROM node:24
WORKDIR /app
COPY . /app
RUN npm install
EXPOSE 3000
ENV NAME=devops-code-challenge2
CMD ["npm", "start"]