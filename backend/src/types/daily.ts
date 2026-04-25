export type DailyQuestion = {
  id: string;
  text: string;
  answer: string;
  options: string[];
  roleTags: string[];
};

export type DailyAnswer = {
  questionId: string;
  answer: string;
  date: string; // YYYY-MM-DD
  answeredAt: string;
};

export type Streak = {
  current: number;
  lastAnsweredDate: string;
};
