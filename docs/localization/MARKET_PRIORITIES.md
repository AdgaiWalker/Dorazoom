# DoraZoom localization market priorities

## Decision

DoraZoom should prioritize markets by the intersection of Apple/Mac purchasing
capacity, creator activity, and the need for a native-language professional
tool—not by population alone. The first binary ships with English as the
development language and nine complete localizations:

| Tier | Countries and regions | App locale | Why now |
| --- | --- | --- | --- |
| A | United States, United Kingdom, Canada, Australia, Singapore, English-speaking professionals in India | `en` | Large creator economies and strong English coverage. |
| A | Mainland China and Simplified-Chinese users | `zh-Hans` | Large video-creator market and strong human–AI content workflows. Store availability requires separate regulatory verification. |
| A | Taiwan, Hong Kong, Macau | `zh-Hant` | Dense creator audience and substantial cross-border viewing. |
| A | Japan | `ja` | Large, locally distinct creator economy; native Japanese is expected for professional Mac software. |
| A | South Korea | `ko` | Large creator economy with strong international reach. |
| A | Germany, Austria, German-speaking Switzerland | `de` | High-value European Mac market and strong localization expectation. |
| A | France, Belgium, French-speaking Switzerland and Canada | `fr` | One localization covers several valuable storefronts. |
| A | Spain | `es-ES` | Spain has its own App Store localization and vocabulary. |
| A | Mexico, Latin America and U.S. Spanish users | `es-419` | Broad regional reach; App Store metadata uses Spanish (Mexico). |
| A | Brazil | `pt-BR` | Major creator economy; Portuguese cannot be substituted with Spanish. |

India remains a Tier-A acquisition market, initially covered in English. Hindi,
Indonesian, Italian, Arabic, Dutch, Polish, Turkish, Thai and Vietnamese are a
second wave selected from App Analytics conversion data. Arabic additionally
requires a complete right-to-left layout pass.

## Evidence

- Apple reports that its global App Store reaches 175 countries and regions,
  and highlights continued growth in spending on content-creation apps:
  https://www.apple.com/newsroom/2025/06/global-app-store-helps-developers-reach-new-heights/
- Apple explains that localized metadata affects display language and localized
  keyword search, while English remains the fallback primary localization:
  https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information/
- Apple’s supported App Store localization table distinguishes Spanish (Spain),
  Spanish (Mexico), Portuguese (Brazil), Simplified Chinese and Traditional
  Chinese:
  https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations/
- Adobe’s 2025 creator study surveyed more than 16,000 creators across the U.S.,
  U.K., France, Germany, South Korea, Japan, India and Australia, and reported
  broad use of creative generative AI:
  https://news.adobe.com/news/2025/10/adobe-max-2025-creators-survey
- YouTube/Oxford Economics reports provide creator-economy evidence for the
  United States, United Kingdom, Europe, India, Japan, South Korea and Brazil:
  https://blog.youtube/news-and-events/2024-us-youtube-impact-report/
  https://blog.youtube/inside-youtube/uk-creator-consultation-report/
  https://blog.youtube/inside-youtube/2025-youtube-europe-impact-report/
  https://blog.google/intl/en-in/products/platforms/how-youtube-is-fueling-indias-next-wave-of-growth-knowledge-and-culture/
  https://blog.youtube/intl/ja-jp/news-and-events/2024-jp-youtube-impact-report/
  https://blog.youtube/intl/ko-kr/news-and-events/2024-kr-youtube-impact-report/
  https://blog.youtube/intl/pt-br/news-and-events/relatorio-de-impacto-do-youtube-2026/
- Taiwan’s 2025 YouTube Brandcast reports broad local reach and meaningful
  overseas viewing for Taiwanese channels:
  https://blog.google/intl/zh-tw/products/explore-get-answers/2025-youtube-brandcast/
- China’s Network Audiovisual Association reports the scale of China’s online
  audiovisual market and increasing human–AI production workflows:
  https://www.cnsa.cn/art/2026/4/24/art_1955_48731.html

## Inference boundary

No authoritative dataset directly measures demand for a Mac screen-annotation
app by country. These priorities are an inference from creator-economy scale,
Apple commercial activity, language coverage efficiency and localization
expectations. YouTube data includes every device and is not a direct estimate
of DoraZoom’s addressable market.
