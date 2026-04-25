export type CounselorProfile = {
  name: string;
  description: string;
  /** e.g. ["資訊領域", "管理", "製造業"] */
  expertise: string[];
  email: string;
  createdAt: string;
  updatedAt: string;
};

export type CounselorProfileInput = Omit<
  CounselorProfile,
  "createdAt" | "updatedAt"
>;
