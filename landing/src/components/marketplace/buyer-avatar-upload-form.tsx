"use client";

import { useRef, useState } from "react";

import { Button } from "@/components/ui/button";

type BuyerAvatarUploadFormProps = {
  action: (formData: FormData) => void | Promise<void>;
};

export function BuyerAvatarUploadForm({ action }: BuyerAvatarUploadFormProps) {
  const formRef = useRef<HTMLFormElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const [selectedFileName, setSelectedFileName] = useState<string | null>(null);

  function openFilePicker() {
    inputRef.current?.click();
  }

  function uploadSelectedFile() {
    const file = inputRef.current?.files?.[0] ?? null;
    if (!file) {
      return;
    }

    setSelectedFileName(file.name);
    formRef.current?.requestSubmit();
  }

  return (
    <form
      ref={formRef}
      action={action}
      className="mt-8 rounded-2xl border border-artisan-clay bg-background p-4"
    >
      <p className="text-sm font-medium text-foreground">Profile photo</p>
      <p className="mt-1 text-sm text-muted-foreground">
        Choose an image and we will upload it to your profile.
      </p>
      <input
        ref={inputRef}
        name="avatar"
        type="file"
        accept="image/*"
        className="sr-only"
        onChange={uploadSelectedFile}
      />
      <div className="mt-4 flex flex-col gap-3 sm:flex-row sm:items-center">
        <Button type="button" variant="outline" className="rounded-full" onClick={openFilePicker}>
          Upload photo
        </Button>
        {selectedFileName ? (
          <span className="text-sm text-muted-foreground">Uploading {selectedFileName}...</span>
        ) : null}
      </div>
    </form>
  );
}
