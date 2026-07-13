"use client";

import Image from "next/image";
import Link from "next/link";
import { useActionState, useEffect, useState, type ChangeEvent, type FormEvent } from "react";
import { useFormStatus } from "react-dom";

import { Button } from "@/components/ui/button";
import {
  submitVendorApplication,
  type VendorApplicationState,
} from "@/app/vendor/actions";
import { validateVendorProofFiles } from "@/lib/marketplace/vendor-application-files";

const initialState: VendorApplicationState = { error: null };

const inputClass =
  "w-full rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm outline-none transition focus:border-artisan-terracotta";

type ProofImagePreview = {
  key: string;
  name: string;
  url: string;
};

function SubmitButton({ hasFileError }: { hasFileError: boolean }) {
  const { pending } = useFormStatus();

  return (
    <Button
      type="submit"
      disabled={pending || hasFileError}
      className="rounded-full bg-artisan-terracotta hover:bg-artisan-terracotta/90"
    >
      {pending ? "Submitting…" : "Submit application"}
    </Button>
  );
}

export function VendorApplicationForm({
  defaultEmail,
  defaultName,
}: {
  defaultEmail?: string | null;
  defaultName?: string | null;
}) {
  const [state, formAction] = useActionState(submitVendorApplication, initialState);
  const [fileError, setFileError] = useState<string | null>(null);
  const [proofImagePreviews, setProofImagePreviews] = useState<ProofImagePreview[]>([]);

  useEffect(
    () => () => {
      proofImagePreviews.forEach((preview) => URL.revokeObjectURL(preview.url));
    },
    [proofImagePreviews],
  );

  function validateSelectedFiles(files: FileList | null) {
    const error = validateVendorProofFiles(files ? Array.from(files) : []);
    setFileError(error);
    return error;
  }

  function handleProofImagesChange(event: ChangeEvent<HTMLInputElement>) {
    const files = event.currentTarget.files ? Array.from(event.currentTarget.files) : [];
    validateSelectedFiles(event.currentTarget.files);
    setProofImagePreviews(
      files.map((file) => ({
        key: `${file.name}-${file.size}-${file.lastModified}`,
        name: file.name,
        url: URL.createObjectURL(file),
      })),
    );
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    const input = event.currentTarget.elements.namedItem("proofImages");
    const error = input instanceof HTMLInputElement ? validateSelectedFiles(input.files) : null;

    if (error) {
      event.preventDefault();
    }
  }

  return (
    <form action={formAction} onSubmit={handleSubmit} className="grid gap-5">
      <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
        Business / shop name
        <input
          name="businessName"
          required
          defaultValue={defaultName ?? ""}
          placeholder="e.g. Clay & Co. Ceramics"
          className={inputClass}
        />
      </label>

      <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
        Location
        <input name="location" placeholder="City, province" className={inputClass} />
      </label>

      <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
        Tell us about your craft
        <textarea
          name="motivation"
          rows={4}
          placeholder="What do you make, and why do you want to sell on Artisan Lane?"
          className={`${inputClass} min-h-28`}
        />
      </label>

      <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
        Portfolio or social link
        <input
          name="portfolioUrl"
          type="url"
          placeholder="https://instagram.com/yourshop"
          className={inputClass}
        />
        <span className="text-xs font-normal text-muted-foreground">
          A portfolio link or product photos below is required so we can review your work.
        </span>
      </label>

      <div className="grid gap-5 md:grid-cols-2">
        <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
          Delivery / shipping approach
          <input
            name="deliveryInfo"
            placeholder="e.g. Courier nationwide, market pickup"
            className={inputClass}
          />
        </label>
        <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
          Typical turnaround time
          <input
            name="turnaroundTime"
            placeholder="e.g. 3–5 business days"
            className={inputClass}
          />
        </label>
      </div>

      <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
        Proof of your work
        <input
          name="proofImages"
          type="file"
          accept="image/jpeg,image/png,image/webp"
          multiple
          onChange={handleProofImagesChange}
          className="text-sm"
        />
        <span className="text-xs font-normal text-muted-foreground">
          Required if you don&apos;t have a portfolio link — up to 5 JPEG, PNG, or WebP photos,
          4 MB combined.
        </span>
      </label>

      {proofImagePreviews.length > 0 ? (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-5" aria-label="Selected proof image previews">
          {proofImagePreviews.map((preview) => (
            <figure
              key={preview.key}
              className="overflow-hidden rounded-2xl border border-artisan-clay bg-white p-2"
            >
              <div className="relative aspect-square overflow-hidden rounded-xl bg-artisan-bone/40">
                <Image
                  src={preview.url}
                  alt={`Preview of ${preview.name}`}
                  fill
                  sizes="(max-width: 640px) 50vw, 160px"
                  className="object-cover"
                  unoptimized
                />
              </div>
              <figcaption className="mt-2 truncate text-xs text-muted-foreground" title={preview.name}>
                {preview.name}
              </figcaption>
            </figure>
          ))}
        </div>
      ) : null}

      <label className="flex items-start gap-3 rounded-2xl border border-artisan-clay/70 bg-artisan-bone/30 p-4 text-sm text-muted-foreground">
        <input name="acceptTerms" type="checkbox" className="mt-1" />
        <span>
          I accept the Artisan Lane{" "}
          <Link href="/terms" className="font-medium text-artisan-terracotta underline" target="_blank">
            Terms &amp; Conditions
          </Link>{" "}
          and confirm the information above is accurate.
        </span>
      </label>

      {defaultEmail ? (
        <p className="text-xs text-muted-foreground">
          Submitting as <span className="font-medium text-artisan-sienna">{defaultEmail}</span>.
        </p>
      ) : null}

      {fileError || state.error ? (
        <p className="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {fileError ?? state.error}
        </p>
      ) : null}

      <div>
        <SubmitButton hasFileError={Boolean(fileError)} />
      </div>
    </form>
  );
}
