import type { Metadata } from "next";
import { headers } from "next/headers";
import "./globals.css";

const title = "DoraZoom — 就在屏幕上，指给他看";
const description = "不用切应用，也不用重复解释。放大、圈画、截图和录制，都留在当前画面。";

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
      images: [{ url: `${origin}/og.png`, width: 1440, height: 900, alt: "DoraZoom — 就在屏幕上，指给他看" }],
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
