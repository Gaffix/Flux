````markdown
# 🚀 Flux — Guia de Configuração e Execução

Este guia explica, passo a passo, como configurar o ambiente necessário para rodar o projeto **Flux**, incluindo o app Flutter, o servidor em Docker e o túnel externo via Ngrok.

---

## 📋 Pré-requisitos

Antes de começar, instale:

- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- [Git](https://git-scm.com/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- Conta no [Ngrok](https://ngrok.com/)

---

## 🌐 1. Configurando o Ngrok

1. Acesse o site do Ngrok e faça login.
2. Baixe o executável do Ngrok.
3. No painel do Ngrok, copie sua **authtoken**.
4. Abra o terminal e execute:

   ```bash
   ngrok config add-authtoken SUA_CHAVE_AQUI
````

5. Teste se está funcionando:

   ```bash
   ngrok http 9000
   ```

### ❗ Caso o comando não funcione

Se o terminal não reconhecer `ngrok`:

1. Aperte **Windows**
2. Pesquise por **"variáveis de ambiente"**
3. Clique em **Editar as variáveis de ambiente do sistema**
4. Acesse **Variáveis de Ambiente → Path**
5. Adicione o caminho da pasta onde está o executável do Ngrok

---

## 📦 2. Clonando o Projeto

```bash
git clone <URL_DO_REPOSITORIO>
cd flux
flutter pub get
```

---

## 📱 3. Rodando o App Flutter no Celular

1. Conecte seu celular via USB com depuração ativada
2. Execute:

   ```bash
   flutter run lib/main.dart
   ```

O app será iniciado no dispositivo.

---

## 🐳 4. Configurando e Rodando o Servidor com Docker

1. Abra o **Docker Desktop**

2. No terminal, vá até a pasta `server` do projeto:

   ```bash
   cd server
   ```

3. Construa o ambiente Docker:

   ```bash
   docker build -t flux .
   ```

4. Inicie o container:

   ```bash
   docker run -p 9000:9000 flux
   ```

O servidor estará rodando localmente na porta **9000**.

---

## 🔗 5. Expondo o Servidor com Ngrok

Em **um novo terminal**, execute:

```bash
ngrok http 9000
```

O Ngrok irá gerar um endereço público na seção:

```
Forwarding
```

Copie esse endereço.

---

## ⚙️ 6. Conectando o App ao Servidor

1. Abra o aplicativo no celular
2. Clique no ícone de **engrenagem**
3. Cole o endereço gerado pelo Ngrok (Forwarding) no campo indicado

---

## ✅ Pronto!

Agora o aplicativo está conectado ao servidor local através do túnel do Ngrok e totalmente funcional.

```
```

