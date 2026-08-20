FROM node:24-slim

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy the agent files
COPY agent.js fetch_segments.js segment_parser.js ingest_segment.js one_shot.js config.js console_log_capture.js loki.js probe_console_logs.js ./

# Create a non-root user
RUN useradd --create-home --shell /bin/bash screeps && \
    chown -R screeps:screeps /app
USER screeps

# Set environment variables
ENV NODE_ENV=production
ENV VICTORIA_METRICS_URL="http://victoriametrics:8428"

# Run the agent
CMD ["node", "agent.js"]