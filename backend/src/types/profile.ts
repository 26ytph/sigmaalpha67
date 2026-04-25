export type Profile = {
  name: string;
  age: string;
  contact: string;
  department: string;
  grade: string;
  location: string;
  currentStage: string;
  goals: string[];
  interests: string[];
  experiences: string[];
  educationItems: string[];
  concerns: string;
  startupInterest: boolean;
  createdAt: string;
  updatedAt: string;
};

export type ProfileInput = Omit<Profile, "createdAt" | "updatedAt">;
