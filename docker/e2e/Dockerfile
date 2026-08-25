FROM mcr.microsoft.com/playwright:v1.62.1-noble@sha256:dcc5531e97840b9b5e794f2814476b21571c5124a3fca2267d73041f56e7580e

WORKDIR /work

COPY tests/e2e/package.json tests/e2e/package-lock.json ./
RUN npm ci --ignore-scripts --no-audit --no-fund \
    && npm cache clean --force

COPY tests/e2e/ ./

RUN chown -R pwuser:pwuser /work

USER pwuser

ENTRYPOINT ["/work/entrypoint.sh"]
CMD ["npm", "test"]
