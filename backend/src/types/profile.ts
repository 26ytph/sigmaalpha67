export type EducationEntry = {
  school: string;
  department: string;
  grade: string;
};

export type Profile = {
  name: string;
  /** 'YYYY-MM-DD' or empty */
  birthday: string;
  email: string;
  phone: string;
  school: string;
  department: string;
  grade: string;
  location: string;
  currentStage: string;
  goals: string[];
  interests: string[];
  experiences: string[];
  educationItems: EducationEntry[];
  concerns: string;
  startupInterest: boolean;
  createdAt: string;
  updatedAt: string;

  // —— legacy fields (keep so old routes still compile while we migrate) ——
  /** @deprecated Use `birthday` + derive age. */
  age?: string;
  /** @deprecated Use `email` + `phone`. */
  contact?: string;
};

export type ProfileInput = Omit<Profile, "createdAt" | "updatedAt">;
