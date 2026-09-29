import { ChatLiveRefresh } from "@/components/marketplace/chat-live-refresh";

export default function MessagesLayout({ children }: { children: React.ReactNode }) {
  return <><ChatLiveRefresh />{children}</>;
}
