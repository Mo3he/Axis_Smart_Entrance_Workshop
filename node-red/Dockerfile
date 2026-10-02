FROM nodered/node-red:4.1

RUN npm install --no-audit --no-fund --omit=dev @flowfuse/node-red-dashboard@1

# Starter flow: preconfigured broker and dashboard layout. Only copied into a fresh volume.
COPY --chown=node-red:node-red flows.json /data/flows.json
