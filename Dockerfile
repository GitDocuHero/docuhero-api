FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npx prisma generate
RUN npm run build

# Remove dev dependencies to reduce image size
RUN npm prune --production

EXPOSE 8080

CMD ["npm", "start"]