# Barbearia Julio Caetano — configuração de produção

## 1. Supabase
1. Crie um projeto Supabase.
2. Execute `supabase/schema.sql` no SQL Editor.
3. Preencha `supabase-config.js` com Project URL e publishable key (ou anon key).
4. Em Authentication → Providers, habilite Google OAuth e configure Client ID/Secret no Google Cloud.
5. Em Authentication → Multi-Factor Authentication, habilite Phone MFA.
6. Configure um provedor compatível com WhatsApp (Twilio Verify) e o template/credenciais exigidos pelo Supabase.
7. Configure as URLs de redirect do site em Authentication → URL Configuration.

## 2. Proprietário
Depois que o proprietário criar a conta Google, execute no SQL Editor:
```sql
insert into public.user_roles(user_id, role)
select id, 'owner' from auth.users where email = 'EMAIL_GOOGLE_DO_PROPRIETARIO'
on conflict (user_id) do update set role = 'owner';
```

## 3. Avatares
A interface usa DiceBear Notionists via pacote JavaScript e gera SVG localmente a partir de uma seed aleatória. A seed fica no perfil do usuário; o mesmo avatar reaparece em novos acessos. Não é necessária chave de API DiceBear.

## Importante
A chave service_role nunca deve ser colocada no navegador. Use somente a chave pública. O esquema aplica RLS às tabelas.
