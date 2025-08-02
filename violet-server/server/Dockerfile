FROM node:22-alpine as builder

ENV NODE_ENV build

USER node
WORKDIR /home/node

COPY package*.json ./

COPY --chown=node:node . .

RUN npm install --legacy-peer-deps
RUN npm run build --legacy-peer-deps \
  && npm prune --production --legacy-peer-deps

# ---

FROM node:22-alpine

ENV NODE_ENV prod

USER node
WORKDIR /home/node

COPY --from=builder --chown=node:node /home/node/package*.json ./
COPY --from=builder --chown=node:node /home/node/node_modules/ ./node_modules/
COPY --from=builder --chown=node:node /home/node/dist/ ./dist/

CMD ["node", "dist/main.js"]