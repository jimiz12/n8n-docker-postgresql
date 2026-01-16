FROM n8nio/n8n:latest
USER root
RUN npm install -g pdf-parse
RUN mkdir -p /tmp/n8n-files && chown node:node /tmp/n8n-files
USER node