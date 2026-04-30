from pydantic import BaseModel, Field


class WebhookResponse(BaseModel):
    status: str
    forwarded: int = 0
    errors: list[str] = Field(default_factory=list)
