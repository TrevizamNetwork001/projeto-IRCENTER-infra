# Infraestrutura do IRCENTER

Este repositório versiona somente a infraestrutura e a documentação operacional
compartilhada do IRCENTER.

As aplicações em `app/` e `documentation-app/` são repositórios Git
independentes e não fazem parte deste histórico. Dados persistentes, arquivos de
ambiente, backups, logs, certificados e segredos também não são versionados.

Alterações neste repositório não implicam deploy automático. Build, recriação de
containers, reinício de serviços e mudanças no host devem seguir runbook e
aprovação operacional.
