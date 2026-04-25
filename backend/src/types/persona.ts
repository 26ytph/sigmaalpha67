export type Persona = {
  text: string;
  careerStage: string;
  mainInterests: string[];
  strengths: string[];
  skillGaps: string[];
  mainConcerns: string[];
  recommendedNextStep: string;
  lastUpdated: string;
  userEdited: boolean;
};

export type PersonaGenerateInput = {
  profile: Partial<import("./profile").Profile> | null;
  explore?: {
    likedRoleIds?: string[];
    dislikedRoleIds?: string[];
  };
  skillTranslations?: Array<{
    rawExperience: string;
    groups: Array<{ experience: string; skills: string[] }>;
  }>;
  previousPersona?: Persona | null;
};
