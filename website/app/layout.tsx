import type { Metadata } from "next";
import { headers } from "next/headers";
import "./globals.css";

const title = "DoraZoom — 把注意力带到你正在讲的地方";
const description = "为 Mac 上的讲解者而做。一个快捷键，放大、圈画、截图或录制。无需账号，本地运行。";

export async function generateMetadata(): Promise<Metadata> {
  const requestHeaders = await headers();
  const host = requestHeaders.get("x-forwarded-host") ?? requestHeaders.get("host") ?? "localhost:3000";
  const protocol = requestHeaders.get("x-forwarded-proto") ?? (host.startsWith("localhost") ? "http" : "https");
  const origin = `${protocol}://${host}`;

  return {
    title,
    description,
    icons: {
      icon: "/dorazoom-icon.png",
      shortcut: "/dorazoom-icon.png",
      apple: "/dorazoom-icon.png",
    },
    openGraph: {
      title,
      description,
      type: "website",
      locale: "zh_CN",
      images: [{ url: `${origin}/og.png`, width: 1536, height: 1024, alt: "DoraZoom 官网预览" }],
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      images: [`${origin}/og.png`],
    },
  };
}

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
