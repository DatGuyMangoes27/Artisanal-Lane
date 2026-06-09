"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Cropper, { type Area } from "react-easy-crop";
import { ImagePlus, X } from "lucide-react";

import { Button } from "@/components/ui/button";

type PickedImage = {
  id: string;
  file: File;
  previewUrl: string;
};

const OUTPUT_SIZE = 1200;

async function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.addEventListener("load", () => resolve(image));
    image.addEventListener("error", (error) => reject(error));
    image.src = src;
  });
}

async function cropToSquareFile(
  imageSrc: string,
  area: Area,
  fileName: string,
): Promise<File> {
  const image = await loadImage(imageSrc);
  const canvas = document.createElement("canvas");
  canvas.width = OUTPUT_SIZE;
  canvas.height = OUTPUT_SIZE;
  const ctx = canvas.getContext("2d");
  if (!ctx) {
    throw new Error("Unable to process image.");
  }

  ctx.drawImage(
    image,
    area.x,
    area.y,
    area.width,
    area.height,
    0,
    0,
    OUTPUT_SIZE,
    OUTPUT_SIZE,
  );

  const blob = await new Promise<Blob | null>((resolve) =>
    canvas.toBlob(resolve, "image/jpeg", 0.9),
  );
  if (!blob) {
    throw new Error("Unable to process image.");
  }

  const baseName = fileName.replace(/\.[^.]+$/, "") || "photo";
  return new File([blob], `${baseName}.jpg`, { type: "image/jpeg" });
}

export function ProductImagePicker({ name = "productImages" }: { name?: string }) {
  const [images, setImages] = useState<PickedImage[]>([]);
  const [queue, setQueue] = useState<{ src: string; fileName: string }[]>([]);
  const [crop, setCrop] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [croppedArea, setCroppedArea] = useState<Area | null>(null);

  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const hiddenInputRef = useRef<HTMLInputElement | null>(null);

  // Keep the real (form-submitted) file input in sync with the cropped images.
  useEffect(() => {
    const input = hiddenInputRef.current;
    if (!input) return;
    const dataTransfer = new DataTransfer();
    images.forEach((item) => dataTransfer.items.add(item.file));
    input.files = dataTransfer.files;
  }, [images]);

  useEffect(() => {
    return () => {
      images.forEach((item) => URL.revokeObjectURL(item.previewUrl));
      queue.forEach((item) => URL.revokeObjectURL(item.src));
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const current = queue[0] ?? null;

  const handleFilesSelected = useCallback(
    (fileList: FileList | null) => {
      if (!fileList || fileList.length === 0) return;
      const next = Array.from(fileList)
        .filter((file) => file.type.startsWith("image/"))
        .map((file) => ({ src: URL.createObjectURL(file), fileName: file.name }));
      if (next.length > 0) {
        setQueue((prev) => [...prev, ...next]);
      }
      if (fileInputRef.current) {
        fileInputRef.current.value = "";
      }
    },
    [],
  );

  const closeCurrent = useCallback(() => {
    setQueue((prev) => {
      const [first, ...rest] = prev;
      if (first) URL.revokeObjectURL(first.src);
      return rest;
    });
    setCrop({ x: 0, y: 0 });
    setZoom(1);
    setCroppedArea(null);
  }, []);

  const confirmCrop = useCallback(async () => {
    if (!current || !croppedArea) return;
    try {
      const file = await cropToSquareFile(current.src, croppedArea, current.fileName);
      setImages((prev) => [
        ...prev,
        { id: crypto.randomUUID(), file, previewUrl: URL.createObjectURL(file) },
      ]);
    } catch {
      // Ignore a single failed crop; the user can retry.
    } finally {
      closeCurrent();
    }
  }, [current, croppedArea, closeCurrent]);

  const removeImage = useCallback((id: string) => {
    setImages((prev) => {
      const target = prev.find((item) => item.id === id);
      if (target) URL.revokeObjectURL(target.previewUrl);
      return prev.filter((item) => item.id !== id);
    });
  }, []);

  return (
    <div className="grid gap-3">
      <input
        ref={hiddenInputRef}
        type="file"
        name={name}
        accept="image/*"
        multiple
        className="hidden"
        aria-hidden
        tabIndex={-1}
      />
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        multiple
        className="hidden"
        onChange={(event) => handleFilesSelected(event.target.files)}
      />

      {images.length > 0 ? (
        <div className="grid grid-cols-3 gap-3 sm:grid-cols-4">
          {images.map((item) => (
            <div
              key={item.id}
              className="group relative aspect-square overflow-hidden rounded-2xl border border-artisan-clay bg-secondary"
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={item.previewUrl}
                alt="New product photo"
                className="h-full w-full object-cover"
              />
              <button
                type="button"
                onClick={() => removeImage(item.id)}
                className="absolute right-1.5 top-1.5 rounded-full bg-black/60 p-1 text-white transition hover:bg-black/80"
                aria-label="Remove photo"
              >
                <X className="h-3.5 w-3.5" />
              </button>
            </div>
          ))}
        </div>
      ) : null}

      <Button
        type="button"
        variant="outline"
        onClick={() => fileInputRef.current?.click()}
        className="w-fit rounded-full border-artisan-clay"
      >
        <ImagePlus className="mr-2 h-4 w-4" />
        Add &amp; crop photos
      </Button>
      <p className="text-xs text-muted-foreground">
        Photos are cropped to a square so your shop looks consistent.
      </p>

      {current ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4">
          <div className="flex w-full max-w-lg flex-col gap-4 rounded-3xl bg-background p-5 shadow-2xl">
            <div className="flex items-center justify-between">
              <h4 className="text-lg font-semibold text-artisan-sienna">Crop photo</h4>
              <button
                type="button"
                onClick={closeCurrent}
                className="rounded-full p-1 text-muted-foreground transition hover:bg-secondary"
                aria-label="Cancel crop"
              >
                <X className="h-5 w-5" />
              </button>
            </div>
            <div className="relative h-72 w-full overflow-hidden rounded-2xl bg-black">
              <Cropper
                image={current.src}
                crop={crop}
                zoom={zoom}
                aspect={1}
                onCropChange={setCrop}
                onZoomChange={setZoom}
                onCropComplete={(_, areaPixels) => setCroppedArea(areaPixels)}
              />
            </div>
            <label className="flex items-center gap-3 text-xs font-medium text-muted-foreground">
              Zoom
              <input
                type="range"
                min={1}
                max={3}
                step={0.01}
                value={zoom}
                onChange={(event) => setZoom(Number(event.target.value))}
                className="flex-1 accent-artisan-terracotta"
              />
            </label>
            <div className="flex justify-end gap-2">
              <Button type="button" variant="ghost" onClick={closeCurrent}>
                Cancel
              </Button>
              <Button
                type="button"
                onClick={confirmCrop}
                className="rounded-full bg-artisan-terracotta hover:bg-artisan-terracotta/90"
              >
                Use photo
              </Button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
