FROM node:20-alpine as build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
# .env dosyasını override edebilmek için argüman alıyoruz
ARG VITE_API_URL
ENV VITE_API_URL=$VITE_API_URL
RUN npm run build

# Nginx ile static dosyaları hostlama
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html

# İsteğe bağlı custom Nginx config eklenebilir
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
