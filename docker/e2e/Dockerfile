FROM mcr.microsoft.com/playwright:v1.55.0-noble@sha256:b27e719ecbfef153e13fd24e8341736733bf2658b229677eb21ff57ff5d7fb29

WORKDIR /work

COPY tests/e2e/package.json tests/e2e/package-lock.json ./
RUN npm ci --ignore-scripts --no-audit --no-fund \
    && npm cache clean --force

COPY tests/e2e/ ./

RUN chown -R pwuser:pwuser /work

USER pwuser

ENTRYPOINT ["/work/entrypoint.sh"]
CMD ["npm", "test"]
