# CRM HUB – By Plotting Engage
## Guia de Configuração Completo

---

## 1. CRIAR PROJECTO SUPABASE

1. Aceda a https://supabase.com e crie uma conta gratuita
2. Clique em **New Project** → escolha um nome (ex: `crm-hub`) e uma senha
3. Aguarde a criação do projecto (~2 min)

---

## 2. EXECUTAR O SCHEMA DA BASE DE DADOS

1. No painel Supabase → **SQL Editor** (menu lateral)
2. Clique em **New query**
3. Cole todo o conteúdo do ficheiro `supabase-schema.sql`
4. Clique em **Run** (▶️)
5. Deve ver a mensagem: *Success. No rows returned*

---

## 3. CRIAR OS BUCKETS DE ARMAZENAMENTO

No painel Supabase → **Storage** → **New bucket** (crie os 4 seguintes):

| Nome             | Público? |
|------------------|----------|
| `avatars`        | ✅ Sim   |
| `logos`          | ✅ Sim   |
| `project-images` | ✅ Sim   |
| `documents`      | ❌ Não   |

Para cada bucket público, defina a política de acesso:
- Storage → Bucket → Policies → New Policy → **"Give users access to only their own top level folder"** (ou "Full access to authenticated users")

---

## 4. OBTER AS CREDENCIAIS SUPABASE

1. No painel Supabase → **Settings** → **API**
2. Copie:
   - **Project URL** (ex: `https://xyzabcde.supabase.co`)
   - **anon public** key (chave longa)

---

## 5. CONFIGURAR O FICHEIRO index.html

Abra `index.html` e localize as linhas no topo do script:

```javascript
const SUPABASE_URL  = 'https://SEU-PROJECTO.supabase.co';
const SUPABASE_KEY  = 'SUA-CHAVE-ANONIMA-PUBLICA';
```

Substitua pelos valores copiados no passo anterior.

---

## 6. CONFIGURAR AUTENTICAÇÃO

No painel Supabase → **Authentication** → **Settings**:

1. **Email** → desactive "Confirm email" (para testes) ou configure SMTP
2. **URL Configuration** → adicione a URL do seu site em "Site URL" e "Redirect URLs"

---

## 7. CRIAR O PRIMEIRO UTILIZADOR MASTER

**Opção A – Via interface da aplicação:**
1. Abra `index.html` no browser
2. Clique em **CRIAR CONTA**
3. Preencha os dados (o primeiro utilizador será automaticamente Master)

**Opção B – Via Supabase Dashboard:**
1. Authentication → Users → **Add user**
2. Depois no SQL Editor execute:
```sql
UPDATE profiles 
SET role = 'master', 
    company_id = 'ID_DA_SUA_EMPRESA'
WHERE email = 'seu@email.com';
```

---

## 8. EXECUTAR A APLICAÇÃO

### Opção A – Abrir directamente no browser
Simplesmente abra `index.html` num browser moderno (Chrome, Firefox, Edge).

### Opção B – Servidor local (recomendado)
```bash
# Com Python
python3 -m http.server 8080

# Com Node.js
npx serve .

# Com PHP
php -S localhost:8080
```
Depois aceda a `http://localhost:8080`

### Opção C – Deploy no Vercel/Netlify
- Arraste a pasta `crm-hub` para vercel.com ou netlify.com
- Deploy automático em segundos

---

## 9. ESTRUTURA DE FICHEIROS

```
crm-hub/
├── index.html          ← Aplicação completa (SPA)
├── supabase-schema.sql ← Schema da base de dados
└── README.md           ← Este ficheiro
```

---

## 10. FUNCIONALIDADES IMPLEMENTADAS

### 🔐 Autenticação
- [x] Login com email/senha
- [x] Registo com dados da empresa
- [x] Recuperação de senha
- [x] Gestão de sessão automática
- [x] 3 níveis: Master / Administrador / Colaborador

### 📁 Gestão de Projectos
- [x] Criar projectos com imagem/logótipo
- [x] Listar projectos por empresa/equipa
- [x] Atribuir utilizadores por projecto

### 🗺️ Construção de Plantas (Floor Plan Builder)
- [x] Criar múltiplas plantas por projecto
- [x] Definir dimensões em metros
- [x] Desenhar corredores (arrastando no grid)
- [x] Marcar stands (arrastando no grid)
- [x] Numeração automática de stands
- [x] Visualização de stands livres/alugadas

### 🏪 Gestão de Stands
- [x] Ver stands disponíveis e ocupadas (verde/vermelho)
- [x] Registar aluguel com dados do cliente
- [x] Anexar documentos (PDF, imagens)
- [x] Cancelar aluguel (apenas admin)
- [x] Ver informações do cliente na stand

### 📋 My List
- [x] Lista completa de todos os aluguéis
- [x] Pesquisa por cliente/stand
- [x] Filtrar por estado (activo/cancelado)
- [x] Ver e editar detalhes de cada aluguel
- [x] Admin: editar / cancelar
- [x] Colaborador: apenas ver / solicitar alteração

### 💬 Mensagens
- [x] Enviar mensagens internas
- [x] Responder a mensagens
- [x] Broadcast para todos os utilizadores

### 🔔 Notificações
- [x] Notificações automáticas de novos aluguéis
- [x] Marcar como lidas
- [x] Indicador visual (dot vermelho)

### 👥 Gestão de Utilizadores
- [x] Ver todos os utilizadores activos/inativos
- [x] Criar novos utilizadores (admin/colaborador)
- [x] Ativar/desativar utilizadores
- [x] Ver histórico de operações por utilizador

### 👤 My Account
- [x] Ver e editar perfil
- [x] Upload de foto de perfil
- [x] Ver empresa e projectos
- [x] Alterar senha

### ⚙️ Definições
- [x] Criar projecto
- [x] Criar utilizador
- [x] Terminar sessão

---

## 11. POLÍTICAS DE SEGURANÇA (RLS)

A aplicação utiliza Row Level Security do Supabase:

| Acção | Master | Admin | Colaborador |
|-------|--------|-------|-------------|
| Criar projecto | ✅ | ✅ | ❌ |
| Editar planta | ✅ | ✅ | ❌ |
| Registar aluguel | ✅ | ✅ | ❌ |
| Cancelar aluguel | ✅ | ✅ | ❌ |
| Ver aluguéis | ✅ | ✅ | ✅ |
| Editar aluguel | ✅ | ✅ | ❌ |
| Criar utilizador | ✅ | ✅ | ❌ |
| Desativar utilizador | ✅ | ✅ | ❌ |
| Ver utilizadores | ✅ | ✅ | ✅ |

---

## 12. SUPORTE E CONTACTO

**By Plotting Engage** – CRM HUB  
Para suporte técnico, consulte a documentação Supabase em https://supabase.com/docs
