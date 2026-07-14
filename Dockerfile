FROM node:20-alpine AS build
WORKDIR /app/admin
COPY admin/package.json admin/package-lock.json* ./
RUN npm install
COPY admin ./
RUN npm run build

FROM node:20-alpine
WORKDIR /app/admin
COPY --from=build /app/admin/.next ./.next
COPY --from=build /app/admin/public ./public
COPY --from=build /app/admin/package.json ./package.json
RUN npm install --omit=dev
EXPOSE 3000
CMD ["npm", "run", "start"]
