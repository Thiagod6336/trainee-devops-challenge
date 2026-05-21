# Trainee DevOps Challenge

Projeto desenvolvido para o desafio técnico do Programa Trainee Cloud & IA.

---

## Tecnologias Utilizadas

- Python 3.12 + Flask
- Docker (multi-stage build, Alpine, usuário não-root)
- Gunicorn (servidor WSGI de produção)
- Pytest + Flake8
- GitLab CI/CD
- Trivy (security scan)
- Terraform (AWS ECS Fargate)

---

## Estrutura do Projeto

```
.
├── app.py                  # Aplicação Flask
├── test_app.py             # Testes unitários
├── requirements.txt        # Dependências Python
├── Dockerfile              # Multi-stage build (Alpine + non-root)
├── docker-compose.yml      # Ambiente local
├── .gitlab-ci.yml          # Pipeline CI/CD (lint → test → build → security → deploy)
├── .gitignore
├── healthcheck.sh          # Script de verificação de saúde da API
└── terraform/
    └── main.tf             # Infraestrutura AWS ECS (Fargate)
```

---

## Como Rodar Localmente

### Pré-requisitos
- Docker >= 24.0 e Docker Compose >= 2.0

### Com Docker Compose (recomendado)

```bash
docker compose up --build
```

A API estará em `http://localhost:5000`

**Endpoints:**
- `GET /` → `{"message": "Trainee DevOps API"}`
- `GET /health` → `{"status": "healthy", "timestamp": "...", "version": "1.0.0"}`

### Verificar saúde da aplicação

```bash
chmod +x healthcheck.sh
./healthcheck.sh localhost 5000
```

### Parar

```bash
docker compose down
```

### Sem Docker (Python direto)

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
pytest test_app.py -v   # testes
python app.py           # iniciar
```

---

## Como o Pipeline Funciona

O `.gitlab-ci.yml` tem 5 stages executados em sequência:

**1. `lint`** — Roda `flake8` no código Python. Falha se houver erros de estilo ou sintaxe.

**2. `test`** — Roda `pytest` com relatório JUnit (visível na UI do GitLab). Falha se algum teste falhar.

**3. `build`** — Build da imagem Docker com duas tags (`<sha-commit>` e `latest`) e push para o GitLab Container Registry. Usa `--cache-from` para reaproveitar camadas de builds anteriores. Roda em `main` e Merge Requests.

**4. `security`** — Escaneia a imagem com **Trivy** (Aqua Security) em busca de CVEs críticas. `allow_failure: true` para não bloquear o deploy. Roda apenas em `main`.

**5. `deploy`** — Simula o deploy no AWS ECS imprimindo os comandos `aws ecs` que seriam executados (register-task-definition → update-service → wait). **Roda somente na branch `main`.**

```
push/commit
    │
    ▼
[lint] → [test] → [build] → [security] → [deploy]
todos     todos   main+MR    main only   main only
```

---

## Terraform (Bônus)

O diretório `terraform/` contém um `main.tf` que provisiona:

- **ECS Cluster** (com Container Insights habilitado)
- **Task Definition** (Fargate, 0.25 vCPU / 512MB RAM, healthcheck nativo)
- **ECS Service** (rolling deploy, mínimo 50% saudável)
- **IAM Role** de execução (permissão para puxar imagem e escrever logs)
- **CloudWatch Log Group** (retenção de 30 dias)

Para usar:
```bash
cd terraform
terraform init
terraform plan -var="container_image=registry.gitlab.com/user/repo:abc123"
terraform apply
```

---

## Decisões Técnicas

**Multi-stage Dockerfile:** O estágio `builder` instala compiladores necessários para alguns pacotes Python. O estágio `runtime` copia apenas os pacotes compilados — sem ferramentas de build na imagem final. Resultado: imagem menor e com menor superfície de ataque.

**Usuário não-root:** Se houver uma vulnerabilidade na aplicação, o atacante terá privilégios mínimos dentro do container. Rodar como root é uma má prática de segurança.

**Gunicorn em vez do Flask dev server:** O servidor embutido do Flask é single-threaded e não recomendado para produção. Gunicorn suporta múltiplos workers e é mais robusto.

**Cache de pip no CI:** Sem cache, cada job baixa todas as dependências do zero. Com cache baseado no hash do `requirements.txt`, a instalação é quase instantânea quando as dependências não mudam.

**Tag com SHA do commit:** Além da tag `latest`, a imagem recebe a tag do SHA do commit — isso permite rastrear exatamente qual código está rodando em produção e facilita rollbacks.

**Trivy com `allow_failure: true`:** Em um projeto real, `allow_failure: false` bloquearia o deploy se houvesse CVEs críticas. Deixei como `true` para não travar o pipeline de demonstração, mas documentado para fácil mudança.

**Terraform com Fargate:** Sem gerenciamento de servidores EC2. A AWS cuida do provisionamento e patching da infraestrutura — menor overhead operacional para um time pequeno.

---

## Como Usei IA neste Desafio

Utilizei o **Claude (Anthropic)** como ferramenta de apoio durante o desafio.

**Para o quê usei:**
- Entender a diferença entre `datetime.utcnow()` (deprecated) e `datetime.now(timezone.utc)` no Python 3.12
- Relembrar a sintaxe de variáveis automáticas do GitLab CI (`CI_REGISTRY_*`, `CI_COMMIT_SHORT_SHA`)
- Verificar boas práticas de segurança no Dockerfile (usuário não-root, multi-stage)
- Revisar a configuração do Trivy no pipeline (flags `--ignore-unfixed`, `--severity`)

**O que escrevi eu mesmo:** Toda a estrutura dos arquivos, a lógica do pipeline, as decisões de arquitetura e o código da aplicação.

**O que a IA me ajudou a corrigir:** Apontou a vírgula faltando no `app.py` e que `from datetime import UTC` não funciona em todas as versões — o correto é `from datetime import timezone` usando `timezone.utc`.

**Aprendizado:** Usar IA como par de revisão de código é muito mais eficiente do que como gerador de código. Eu escrevia, a IA apontava o que estava errado e eu entendia o porquê antes de corrigir.
