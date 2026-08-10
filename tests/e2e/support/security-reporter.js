const fs = require('fs');

class SecurityReporter {
  constructor() {
    this.csp = [];
    this.consoleErrors = [];
  }

  onTestEnd(test, result) {
    for (const attachment of result.attachments) {
      if (!attachment.body) continue;
      if (attachment.name === 'csp-observations') {
        this.csp.push({ test: test.title, entries: JSON.parse(attachment.body.toString()) });
      }
      if (attachment.name === 'console-errors') {
        this.consoleErrors.push({ test: test.title, entries: JSON.parse(attachment.body.toString()) });
      }
    }
  }

  onEnd() {
    fs.mkdirSync('/artifacts', { recursive: true });
    fs.writeFileSync('/artifacts/browser-security.json', JSON.stringify({
      cspViolations: this.csp,
      unexpectedConsoleErrors: this.consoleErrors,
    }, null, 2));
  }
}

module.exports = SecurityReporter;
