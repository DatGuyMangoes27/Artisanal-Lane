export const MAX_VENDOR_PROOF_FILES = 5;
export const MAX_VENDOR_PROOF_TOTAL_BYTES = 4 * 1024 * 1024;

const allowedVendorProofTypes = new Set(["image/jpeg", "image/png", "image/webp"]);

type VendorProofFile = Pick<File, "size" | "type">;

export function validateVendorProofFiles(files: VendorProofFile[]) {
  if (files.length > MAX_VENDOR_PROOF_FILES) {
    return `Please upload no more than ${MAX_VENDOR_PROOF_FILES} photos.`;
  }

  if (files.some((file) => !allowedVendorProofTypes.has(file.type))) {
    return "Please upload only JPEG, PNG, or WebP photos.";
  }

  const totalBytes = files.reduce((total, file) => total + file.size, 0);
  if (totalBytes > MAX_VENDOR_PROOF_TOTAL_BYTES) {
    return "Please keep the combined photo upload under 4 MB, or use a portfolio link instead.";
  }

  return null;
}
