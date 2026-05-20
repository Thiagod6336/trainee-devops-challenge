# Stage 1: Builder — instala dependências
FROM python:3.12-alpine AS builder

RUN apk add --no-cache gcc musl-dev libffi-dev

WORKDIR /install

COPY requirements.txt .

RUN pip install --no-cache-dir --prefix=/install/packages -r requirements.txt

# Stage 2: Runtime — imagem final leve e segura
FROM python:3.12-alpine AS runtime

LABEL maintainer="trainee-devops" version="1.0.0"

# Usuário não-root (segurança)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copia apenas os pacotes compilados do estágio anterior
COPY --from=builder /install/packages /usr/local

COPY app.py .

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:5000/health || exit 1

# Gunicorn: servidor WSGI de produção (não o dev server do Flask)
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:5000", "--access-logfile", "-", "app:app"]
