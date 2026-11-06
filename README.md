# 🚴 Giro ABC – Lista do Pedal

Página onde o pessoal coloca o nome na lista do pedal, a lista atualiza pra todo mundo e o organizador manda tudo formatado pro grupo do WhatsApp.

**Arquivos:** `index.html` (a página), `schema.sql` (o banco), `logo.png` e `capa.jpg`.

> Se você abrir o `index.html` sem configurar nada, ele roda em **MODO DEMO** com dados de exemplo (senha do organizador: `demo`). Bom pra testar o visual.

---

## 1) Criar o banco no Supabase (grátis), uns 5 min

1. Entre em **https://supabase.com**, faça login com o GitHub e clique em **New project**. Use o nome `giro-abc` e a região **South America (São Paulo)**.
2. No menu da esquerda, abra **SQL Editor** e clique em **New query**.
3. Abra o `schema.sql`, **troque `TROQUE-ESSA-SENHA`** (lá no final) pela senha do organizador, cole tudo e clique em **Run**.
4. Vá em **Project Settings → API** e copie:
   - **Project URL** (algo como `https://xxxx.supabase.co`)
   - **anon public key**

## 2) Configurar a página

No topo do `index.html`, preencha:

```js
SUPABASE_URL: "https://xxxx.supabase.co",
SUPABASE_ANON_KEY: "eyJhbGciOi...",
INSTAGRAM: "https://instagram.com/..."   // opcional
```

A chave *anon* é pública, pode ficar no site. A segurança está no banco: ninguém consegue apagar nada nem editar pedais sem a senha do organizador.

## 3) Colocar no ar com o GitHub Pages (grátis), uns 5 min

1. No GitHub, crie um repositório **público** chamado `giro-abc`.
2. Faça upload dos 4 arquivos (`index.html`, `logo.png`, `capa.jpg`, `README.md`).
3. Vá em **Settings → Pages → Source: Deploy from a branch → main / (root) → Save**.
4. Em 1 ou 2 minutos o site sai em: **`https://diegodepauladiego.github.io/giro-abc/`**

**Prévia no WhatsApp:** no `index.html`, troque `SEU-SITE` na linha do `og:image` pelo endereço acima. Assim o link aparece no grupo com a capa do clube.

> Alternativa: na **Vercel** (vercel.com), é só importar o repositório. Ela dá um endereço tipo `giro-abc.vercel.app`.

---

## Como usar no dia a dia

**Criar o pedal da semana**
1. Abra o site, role até o fim e toque em **Área do organizador** (ou abra `.../giro-abc/?admin`).
2. Digite a senha.
3. Toque em **📄 Duplicar este** (copia o último pedal), troque a data e o que mudou e salve.
   Ou toque em **➕ Novo pedal** pra começar do zero.
4. Toque em **Mandar no grupo**. O WhatsApp abre com a mensagem pronta, no mesmo formato de sempre, com o link no final.

**O pessoal**
- Abre o link, digita o nome e toca em **Tô dentro!** Pronto.
- O celular guarda a inscrição, então a pessoa pode tocar em **Sair** se desistir.
- Nome repetido é bloqueado, e aqueles caracteres invisíveis do copiar e colar são removidos.
- Se você definir um limite de **Vagas**, a lista fecha sozinha quando enche.

**Organizador**
- **Remover** aparece do lado de cada nome.
- **Colocar alguém na lista** serve pra quem pediu pelo grupo, e funciona mesmo com a lista fechada.
- Desmarque **Inscrições abertas** pra encerrar a lista.
- Antes de sair, toque em **Mandar no grupo** de novo pra postar a lista final.

**Links**
- `.../giro-abc/` sempre mostra o **próximo pedal** pela data.
- Cada pedal também tem o próprio link (`?pedal=...`). É esse que vai na mensagem.

**Trocar a senha:** rode de novo só o bloco "SENHA DO ORGANIZADOR" do `schema.sql` no SQL Editor, com a senha nova.

**Trocar logo ou capa:** substitua `logo.png` e `capa.jpg` no repositório, com o mesmo nome.

> ℹ️ No plano grátis, o Supabase pausa o projeto depois de 7 dias **sem nenhum acesso**. Como o grupo usa toda semana, isso não deve acontecer. Se pausar, é só entrar no painel do Supabase e clicar em **Restore**.
