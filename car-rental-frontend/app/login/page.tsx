"use client";

import Link from "next/link";
import { useState } from "react";
import { api, setSession, type Session } from "@/lib/api";

export default function Login() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    setError("");
    setBusy(true);
    try {
      const session = await api<Session>("/api/auth/login", {
        method: "POST",
        body: JSON.stringify({ email, password }),
      });
      setSession(session);
      location.href = session.role === "ADMIN" ? "/admin" : "/cars";
    } catch (error) {
      setError((error as Error).message);
      setBusy(false);
    }
  }

  return (
    <section className="auth">
      <form onSubmit={submit}>
        <div className="eyebrow">CHÀO MỪNG TRỞ LẠI</div>
        <h1>Đăng nhập</h1>
        <p className="muted">Quản lý hành trình và các đơn thuê xe của bạn.</p>
        <label>Email<input type="email" value={email} onChange={event => setEmail(event.target.value)} required autoComplete="email" /></label>
        <label>Mật khẩu<input type="password" value={password} onChange={event => setPassword(event.target.value)} required autoComplete="current-password" /></label>
        {error && <p className="error" role="alert">{error}</p>}
        <button className="button" disabled={busy}>{busy ? "Đang đăng nhập..." : "Đăng nhập"}</button>
        <p>Chưa có tài khoản? <Link href="/register">Đăng ký</Link></p>
      </form>
    </section>
  );
}
